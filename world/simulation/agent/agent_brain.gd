extends Node

## AgentBrain - centralized decision-making for all agents.
##
## Computes AgentOrders for ALL agents (online + offline).
## Delegates route tracking to AgentRouteTracker and offline movement to AgentOfflineSim.

## Per-agent computed orders. StringName agent_id -> AgentOrder
var _orders: Dictionary = {}

## Per-agent route trackers. StringName agent_id -> AgentRouteTracker
var _trackers: Dictionary = {}

## Per-agent status reports from spawned NPCs. StringName agent_id -> AgentStatus
var _statuses: Dictionary = {}

func _ready() -> void:
	set_process(false)
	_connect_signals()

func _connect_signals() -> void:
	if TimeManager != null and not TimeManager.time_changed.is_connected(_on_time_changed):
		TimeManager.time_changed.connect(_on_time_changed)

func _on_time_changed(_day_index: int, minute_of_day: int, _day_progress: float) -> void:
	_tick(minute_of_day)

## Main brain tick - runs once per game minute.
func _tick(minute_of_day: int) -> void:
	if AgentRegistry == null or AgentSpawner == null or GameManager == null:
		return

	var active_level_id: Enums.Levels = GameManager.get_active_level_id()
	var spawned_ids: Dictionary = {}
	for id in AgentSpawner.get_spawned_agent_ids():
		spawned_ids[id] = true

	var did_mutate := false
	var needs_sync := false

	for rec in AgentRegistry.list_records():
		if rec == null or rec.kind != Enums.AgentKind.NPC:
			continue

		var cfg: NpcConfig = AgentSpawner.get_npc_config(rec.agent_id)
		var tracker := _ensure_tracker(rec.agent_id)
		var is_online := spawned_ids.has(rec.agent_id)

		# Check for expired travel - warp if needed
		var prev_order: AgentOrder = _orders.get(rec.agent_id) as AgentOrder
		if _should_force_warp(rec, prev_order, cfg, minute_of_day):
			_force_complete_travel(rec, prev_order, tracker)
			did_mutate = true
			# Need to sync if agent was online (to despawn) or is now in active level (to spawn)
			if is_online or rec.current_level_id == active_level_id:
				needs_sync = true

		var order := _compute_order(rec, cfg, tracker, minute_of_day)
		_orders[rec.agent_id] = order

		if not is_online:
			var speed := cfg.move_speed if cfg != null and cfg.move_speed > 0.0 else 22.0
			var result := AgentOfflineSim.apply_order(rec, order, tracker, speed)
			if result.changed:
				did_mutate = true
			if result.committed_travel and rec.current_level_id == active_level_id:
				needs_sync = true

	if did_mutate:
		AgentRegistry.save_to_session()
	if needs_sync:
		AgentSpawner.sync_agents_for_active_level()

#region Public API

func get_order(agent_id: StringName) -> AgentOrder:
	return _orders.get(agent_id) as AgentOrder

func get_tracker(agent_id: StringName) -> AgentRouteTracker:
	return _trackers.get(agent_id) as AgentRouteTracker

func report_status(status: AgentStatus) -> void:
	if status == null or String(status.agent_id).is_empty():
		return

	_statuses[status.agent_id] = status

	if status.reached_target:
		_on_agent_reached_target(status.agent_id)

#endregion


#region Internal

func _on_agent_reached_target(agent_id: StringName) -> void:
	var tracker: AgentRouteTracker = _trackers.get(agent_id) as AgentRouteTracker
	if tracker == null or not tracker.is_active():
		return

	var order: AgentOrder = _orders.get(agent_id) as AgentOrder
	if order == null:
		return

	# Travel route completed? Commit travel.
	if tracker.is_travel_route and tracker.is_at_route_end():
		if order.is_traveling and order.travel_spawn_point != null:
			AgentRegistry.commit_travel_and_sync(agent_id, order.travel_spawn_point)
			order.is_traveling = false
			order.action = AgentOrder.Action.IDLE
			tracker.reset()
			return

	# Advance to next waypoint
	var next_target := tracker.advance()
	if next_target == Vector2.ZERO:
		order.action = AgentOrder.Action.IDLE
	else:
		order.target_position = next_target
		order.action = AgentOrder.Action.MOVE_TO

func _ensure_tracker(agent_id: StringName) -> AgentRouteTracker:
	var tracker: AgentRouteTracker = _trackers.get(agent_id) as AgentRouteTracker
	if tracker == null:
		tracker = AgentRouteTracker.new()
		tracker.agent_id = agent_id
		_trackers[agent_id] = tracker
	return tracker

func _compute_order(
	rec: AgentRecord,
	cfg: NpcConfig,
	tracker: AgentRouteTracker,
	minute_of_day: int
) -> AgentOrder:
	var order := AgentOrder.new()
	order.agent_id = rec.agent_id
	order.facing_dir = Vector2.DOWN

	if cfg == null or cfg.schedule == null:
		order.action = AgentOrder.Action.IDLE
		return order

	var resolved := ScheduleResolver.resolve(cfg.schedule, minute_of_day)
	if resolved == null or resolved.step == null:
		order.action = AgentOrder.Action.IDLE
		return order

	match resolved.step.kind:
		NpcScheduleStep.Kind.ROUTE:
			_apply_route_step(order, rec, tracker, resolved.step)
		NpcScheduleStep.Kind.TRAVEL:
			_apply_travel_step(order, rec, tracker, resolved.step, minute_of_day)
		_:
			order.action = AgentOrder.Action.IDLE

	return order

func _apply_route_step(
	order: AgentOrder,
	rec: AgentRecord,
	tracker: AgentRouteTracker,
	step: NpcScheduleStep
) -> void:
	if step.level_id != Enums.Levels.NONE and rec.current_level_id != step.level_id:
		order.action = AgentOrder.Action.IDLE
		return

	var route: RouteResource = step.route_res
	if route == null:
		order.action = AgentOrder.Action.IDLE
		return

	var route_key := StringName("route:" + String(route.resource_path))
	var waypoints := _get_route_waypoints(route)

	tracker.set_route(route_key, waypoints, rec.last_world_pos, bool(step.loop_route), false)

	if not tracker.is_active():
		order.action = AgentOrder.Action.IDLE
		return

	order.action = AgentOrder.Action.MOVE_TO
	order.target_position = tracker.get_current_target()
	order.is_on_route = true
	order.route_key = route_key
	order.route_progress = tracker.get_progress()

func _apply_travel_step(
	order: AgentOrder,
	rec: AgentRecord,
	tracker: AgentRouteTracker,
	step: NpcScheduleStep,
	minute_of_day: int
) -> void:
	var target_sp := step.target_spawn_point
	if target_sp == null or not target_sp.is_valid():
		order.action = AgentOrder.Action.IDLE
		return

	# Already in destination?
	if rec.current_level_id == target_sp.level_id:
		order.action = AgentOrder.Action.IDLE
		return

	# Set travel metadata
	order.is_traveling = true
	order.travel_spawn_point = target_sp

	if TimeManager != null:
		var remaining := ScheduleResolver.get_step_remaining_minutes(minute_of_day, step)
		order.travel_deadline_abs = int(TimeManager.get_absolute_minute()) + remaining

	# No exit route = instant teleport
	if step.exit_route_res == null:
		order.action = AgentOrder.Action.IDLE
		return

	# Walk exit route
	var route: RouteResource = step.exit_route_res
	var route_key := StringName("travel:" + String(route.resource_path))
	var waypoints := _get_route_waypoints(route)

	tracker.set_route(route_key, waypoints, rec.last_world_pos, false, true)

	if not tracker.is_active():
		order.action = AgentOrder.Action.IDLE
		return

	order.action = AgentOrder.Action.MOVE_TO
	order.target_position = tracker.get_current_target()
	order.is_on_route = true
	order.route_key = route_key

func _get_route_waypoints(route: RouteResource) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if route == null:
		return out

	if route.curve_world != null and route.curve_world.point_count >= 2:
		var baked := route.curve_world.get_baked_points()
		for p in baked:
			out.append(p)
	elif route.points_world.size() > 0:
		for p in route.points_world:
			out.append(p)

	return out

## Check if agent was traveling and is now past deadline (schedule moved on).
func _should_force_warp(
	rec: AgentRecord,
	prev_order: AgentOrder,
	cfg: NpcConfig,
	minute_of_day: int
) -> bool:
	if prev_order == null or not prev_order.is_traveling:
		return false

	var t_past := prev_order.travel_spawn_point
	if t_past == null or rec.current_level_id == t_past.level_id:
		return false

	# Already arrived?
	if rec.current_level_id == t_past.level_id:
		return false

	# No config/schedule = can't determine if still traveling, force warp
	if cfg == null or cfg.schedule == null:
		return true

	# Check if still in a TRAVEL step for the same destination
	var resolved := ScheduleResolver.resolve(cfg.schedule, minute_of_day)
	if resolved == null or not resolved.is_travel_step():
		# No active step = schedule moved on, force warp
		return true

	var t_future := resolved.step.target_spawn_point
	return t_future.level_id != t_past.level_id

## Force-complete a travel by warping the agent to the destination.
func _force_complete_travel(
	rec: AgentRecord,
	prev_order: AgentOrder,
	tracker: AgentRouteTracker
) -> void:
	if prev_order == null or prev_order.travel_spawn_point == null:
		return

	var sp := prev_order.travel_spawn_point
	AgentRegistry.commit_travel_by_id(rec.agent_id, sp)
	tracker.reset()

#endregion
