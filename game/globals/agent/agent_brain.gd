extends Node

## AgentBrain - centralized decision-making for all agents.
##
## Computes AgentOrders for ALL agents (online + offline).
## Delegates route tracking to AgentRouteTracker and offline movement to AgentOfflineSim.
## Manages AgentRegistry and AgentSpawner.

# Exposed properties for access by GameFlow/Runtime
var active_level_id: Enums.Levels = Enums.Levels.NONE
var registry: AgentRegistry
var spawner: AgentSpawner

## Per-agent computed orders. StringName agent_id -> AgentOrder
var _orders: Dictionary = {}

## Per-agent route trackers. StringName agent_id -> AgentRouteTracker
var _trackers: Dictionary = {}

## Per-agent status reports from spawned NPCs. StringName agent_id -> AgentStatus
var _statuses: Dictionary = {}


func _ready() -> void:
	# Instantiate dependencies
	registry = AgentRegistry.new()
	registry.name = "AgentRegistry"
	add_child(registry)

	spawner = AgentSpawner.new()
	spawner.name = "AgentSpawner"
	spawner.setup(registry)
	add_child(spawner)

	set_process(false)
	_connect_signals()


func _connect_signals() -> void:
	if TimeManager != null and not TimeManager.time_changed.is_connected(_on_time_changed):
		TimeManager.time_changed.connect(_on_time_changed)
	if EventBus != null and not EventBus.travel_requested.is_connected(_on_travel_requested):
		EventBus.travel_requested.connect(_on_travel_requested)
	if (
		EventBus != null
		and not EventBus.active_level_changed.is_connected(_on_active_level_changed)
	):
		EventBus.active_level_changed.connect(_on_active_level_changed)


func _on_active_level_changed(_prev: Enums.Levels, next: Enums.Levels) -> void:
	active_level_id = next


func _on_time_changed(_day_index: int, minute_of_day: int, _day_progress: float) -> void:
	_tick(minute_of_day)


func _on_travel_requested(agent: Node, target_spawn_point: SpawnPointData) -> void:
	# Agent domain decides + commits travel. Runtime/GameFlow executes scene changes.
	if agent == null or target_spawn_point == null or not target_spawn_point.is_valid():
		return
	if registry == null:
		return
	if Runtime != null and Runtime.scene_loader.is_loading():
		return

	# Determine agent kind via AgentComponent (preferred), otherwise fall back to group.
	var kind: Enums.AgentKind = Enums.AgentKind.NONE
	var ac := ComponentFinder.find_component_in_group(agent, Groups.AGENT_COMPONENTS)
	if ac is AgentComponent:
		kind = (ac as AgentComponent).kind
	elif agent.is_in_group("player"):
		kind = Enums.AgentKind.PLAYER

	var rec := registry.ensure_agent_registered_from_node(agent) as AgentRecord
	if rec == null:
		return

	if kind == Enums.AgentKind.PLAYER:
		# Player travel: commit record now, persist agents save, then request scene change.
		registry.commit_travel_by_id(rec.agent_id, target_spawn_point)
		var a := registry.save_to_session()
		if a != null and Runtime != null and Runtime.save_manager != null:
			Runtime.save_manager.save_session_agents_save(a)
		if EventBus != null:
			EventBus.level_change_requested.emit(target_spawn_point.level_id, target_spawn_point)
		return

	# NPC travel: commit + persist + sync within agent domain only (no scene change).
	commit_travel_and_sync(rec.agent_id, target_spawn_point)


## Main brain tick - runs once per game minute.
func _tick(minute_of_day: int) -> void:
	if registry == null or spawner == null or Runtime == null:
		return
	# Loading/continue/slot-copy should be quiescent: don't simulate or persist while
	# the session is being replaced/hydrated.
	if Runtime.scene_loader.is_loading():
		return

	var spawned_ids: Dictionary = {}
	for id in spawner.get_spawned_agent_ids():
		spawned_ids[id] = true

	var did_mutate := false
	var needs_sync := false

	for rec in registry.list_records():
		if rec == null or rec.kind != Enums.AgentKind.NPC:
			continue

		var cfg: NpcConfig = spawner.get_npc_config(rec.agent_id)
		var tracker := _ensure_tracker(rec.agent_id)
		var is_online := spawned_ids.has(rec.agent_id)

		# Resolve schedule once per tick per agent
		var resolved: ScheduleResolver.Resolved = null
		if cfg != null and cfg.schedule != null:
			resolved = ScheduleResolver.resolve(cfg.schedule, minute_of_day)

		# Check for expired travel - warp if needed
		var prev_order: AgentOrder = _orders.get(rec.agent_id) as AgentOrder
		if _should_force_warp(rec, prev_order, cfg, resolved):
			_force_complete_travel(rec, prev_order, tracker)
			did_mutate = true
			# Need to sync if agent was online (to despawn) or is now in active level (to spawn)
			if is_online or rec.current_level_id == active_level_id:
				needs_sync = true

		var order := _compute_order(rec, cfg, tracker, resolved)
		_orders[rec.agent_id] = order

		if not is_online:
			var speed := cfg.move_speed if cfg != null and cfg.move_speed > 0.0 else 22.0
			var result := AgentOfflineSim.apply_order(rec, order, tracker, speed, registry)
			if result.changed:
				did_mutate = true
			if result.committed_travel and rec.current_level_id == active_level_id:
				needs_sync = true

	if did_mutate:
		var a := registry.save_to_session()
		if a != null and Runtime != null and Runtime.save_manager != null:
			Runtime.save_manager.save_session_agents_save(a)
	if needs_sync:
		var lr = _get_active_level_root()
		if lr != null:
			spawner.sync_agents_for_active_level(lr)


#region Public API


func get_agent_node(agent_id: StringName) -> Node2D:
	if spawner == null:
		return null
	return spawner.get_agent_node(agent_id)


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


## Convenience: commit travel + persist + sync spawned agents.
## Moved from AgentRegistry.
func commit_travel_and_sync(
	agent_id: StringName, target_spawn_point: SpawnPointData, persist: bool = true
) -> bool:
	if registry == null:
		return false
	var ok := registry.commit_travel_by_id(agent_id, target_spawn_point)
	if not ok:
		return false
	if persist:
		var a := registry.save_to_session()
		if a != null and Runtime != null and Runtime.save_manager != null:
			Runtime.save_manager.save_session_agents_save(a)
	if spawner != null:
		var lr = _get_active_level_root()
		if lr != null:
			spawner.sync_agents_for_active_level(lr)
	return true


func _get_active_level_root() -> LevelRoot:
	var scene := get_tree().current_scene
	if scene is LevelRoot:
		return scene as LevelRoot
	if scene != null:
		var lr = scene.get_node_or_null(NodePath("LevelRoot"))
		if lr is LevelRoot:
			return lr as LevelRoot
	return null


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
			commit_travel_and_sync(agent_id, order.travel_spawn_point)
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
	resolved: ScheduleResolver.Resolved
) -> AgentOrder:
	var order := AgentOrder.new()
	order.agent_id = rec.agent_id

	if cfg == null or cfg.schedule == null:
		order.action = AgentOrder.Action.IDLE
		order.facing_dir = Vector2.DOWN
		return order

	if resolved == null or resolved.step == null:
		order.action = AgentOrder.Action.IDLE
		order.facing_dir = Vector2.DOWN
		return order

	order.facing_dir = resolved.step.facing_dir
	match resolved.step.kind:
		NpcScheduleStep.Kind.ROUTE:
			_apply_route_step(order, rec, tracker, resolved.step)
		NpcScheduleStep.Kind.TRAVEL:
			_apply_travel_step(order, rec, tracker, resolved.step)
		_:
			order.action = AgentOrder.Action.IDLE

	return order


func _apply_route_step(
	order: AgentOrder, rec: AgentRecord, tracker: AgentRouteTracker, step: NpcScheduleStep
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
	order: AgentOrder, rec: AgentRecord, tracker: AgentRouteTracker, step: NpcScheduleStep
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
	rec: AgentRecord, prev_order: AgentOrder, cfg: NpcConfig, resolved: ScheduleResolver.Resolved
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
	if resolved == null or not resolved.is_travel_step():
		# No active step = schedule moved on, force warp
		return true

	var t_future := resolved.step.target_spawn_point
	return t_future.level_id != t_past.level_id


## Force-complete a travel by warping the agent to the destination.
func _force_complete_travel(
	rec: AgentRecord, prev_order: AgentOrder, tracker: AgentRouteTracker
) -> void:
	if prev_order == null or prev_order.travel_spawn_point == null:
		return

	var sp := prev_order.travel_spawn_point
	if registry:
		registry.commit_travel_by_id(rec.agent_id, sp)
	tracker.reset()

#endregion
