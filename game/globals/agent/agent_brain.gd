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

## Per-agent temporary schedule override (for early route chaining).
## StringName agent_id -> int step_index (in cfg.schedule.steps)
var _schedule_override_step_idx: Dictionary = {}
## StringName agent_id -> int minute_of_day at which override expires
var _schedule_override_expire_minute: Dictionary = {}


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
			_apply_schedule_override(rec.agent_id, cfg.schedule, minute_of_day, resolved)

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


#region Day-start schedule reset


## Force all NPCs into their day-start schedule location at a specific minute (typically 06:00).
## This is used by sleep/day-start so NPCs "start their day" deterministically even if offscreen.
func reset_npcs_to_day_start(minute_of_day: int = -1) -> void:
	if registry == null or spawner == null or Runtime == null or TimeManager == null:
		return
	if Runtime.scene_loader != null and Runtime.scene_loader.is_loading():
		return

	var m := minute_of_day
	if m < 0:
		m = int(TimeManager.DAY_TICK_MINUTE)

	var did_mutate := false

	for rec in registry.list_records():
		if rec == null or rec.kind != Enums.AgentKind.NPC:
			continue

		var cfg: NpcConfig = spawner.get_npc_config(rec.agent_id)
		if cfg == null:
			continue

		# Reset per-day movement state so the day starts cleanly.
		var tracker: AgentRouteTracker = _trackers.get(rec.agent_id) as AgentRouteTracker
		if tracker != null:
			tracker.reset()
		_clear_schedule_override(rec.agent_id)
		_orders.erase(rec.agent_id)

		var resolved: ScheduleResolver.Resolved = null
		if cfg.schedule != null:
			resolved = ScheduleResolver.resolve(cfg.schedule, m)

		if resolved == null or resolved.step == null:
			# No schedule step resolved: fall back to initial spawn point (if any).
			if cfg.initial_spawn_point != null and cfg.initial_spawn_point.is_valid():
				registry.commit_travel_by_id(rec.agent_id, cfg.initial_spawn_point)
				did_mutate = true
			continue

		var step := resolved.step
		rec.facing_dir = step.facing_dir

		match step.kind:
			NpcScheduleStep.Kind.ROUTE:
				# Place at a deterministic route start so the day begins consistently.
				if step.route_res == null:
					continue
				var waypoints := _get_route_waypoints(step.route_res)
				if waypoints.is_empty():
					continue
				var start_wp := waypoints[0]
				rec.current_level_id = start_wp.level_id
				rec.last_world_pos = start_wp.position
				rec.last_spawn_point_path = ""
				rec.needs_spawn_marker = false
				rec.last_cell = Vector2i(-1, -1)
				registry.upsert_record(rec)
				did_mutate = true
			_:
				# HOLD (or unknown): ensure a deterministic level/position if we can.
				rec.last_spawn_point_path = ""
				rec.needs_spawn_marker = false
				rec.last_cell = Vector2i(-1, -1)

				var pos := rec.last_world_pos
				var found := rec.current_level_id != Enums.Levels.NONE
				# Prefer config spawn point if we don't have a placement yet.
				if cfg.initial_spawn_point != null and cfg.initial_spawn_point.is_valid():
					if not found:
						rec.current_level_id = cfg.initial_spawn_point.level_id
						pos = cfg.initial_spawn_point.position
						found = true
				# Otherwise fall back to first route waypoint in this level, if any.
				if not found and cfg.schedule != null:
					for s in cfg.schedule.steps:
						if s == null or not s.is_valid():
							continue
						if s.kind == NpcScheduleStep.Kind.ROUTE and s.route_res != null:
							var w := _get_route_waypoints(s.route_res)
							for wp in w:
								if wp.level_id != Enums.Levels.NONE:
									rec.current_level_id = wp.level_id
									pos = wp.position
									found = true
									break
							if found:
								break

				rec.last_world_pos = pos
				registry.upsert_record(rec)
				did_mutate = true

	if did_mutate:
		var a := registry.save_to_session()
		if a != null and Runtime.save_manager != null:
			Runtime.save_manager.save_session_agents_save(a)

		# Ensure the currently active level reflects the reset immediately.
		var lr := _get_active_level_root()
		if lr != null:
			spawner.sync_agents_for_active_level(lr)


#endregion

#endregion

#region Internal


func _on_agent_reached_target(agent_id: StringName) -> void:
	var tracker: AgentRouteTracker = _trackers.get(agent_id) as AgentRouteTracker
	if tracker == null or not tracker.is_active():
		return

	var order: AgentOrder = _orders.get(agent_id) as AgentOrder
	if order == null:
		return

	# Advance to next waypoint
	var next_wp := tracker.advance()
	if next_wp != null:
		_apply_next_waypoint(agent_id, order, next_wp)
		return

	# Route completed. If the next schedule event is another ROUTE, start it immediately.
	_clear_schedule_override(agent_id)
	order.action = AgentOrder.Action.IDLE
	_try_chain_to_next_route(agent_id, order, tracker)


func _apply_next_waypoint(agent_id: StringName, order: AgentOrder, next_wp: WorldPoint) -> void:
	if order == null or next_wp == null:
		return
	var rec = registry.get_record(agent_id)
	if rec != null and next_wp.level_id != rec.current_level_id:
		# Teleport to next level
		var sp := SpawnPointData.new()
		sp.level_id = next_wp.level_id
		sp.position = next_wp.position
		commit_travel_and_sync(agent_id, sp)

	# Continue route from current/new level
	order.target_position = next_wp.position
	order.action = AgentOrder.Action.MOVE_TO


func _try_chain_to_next_route(
	agent_id: StringName, order: AgentOrder, tracker: AgentRouteTracker
) -> void:
	if (
		order == null
		or tracker == null
		or registry == null
		or spawner == null
		or TimeManager == null
	):
		return

	var rec0 := registry.get_record(agent_id) as AgentRecord
	var cfg0: NpcConfig = spawner.get_npc_config(agent_id)
	if rec0 == null or cfg0 == null or cfg0.schedule == null:
		return

	var minute := int(TimeManager.get_minute_of_day())
	var resolved0 := ScheduleResolver.resolve(cfg0.schedule, minute)
	if resolved0 == null or resolved0.step == null:
		return

	# Only chain if we were on a non-loop route step.
	if resolved0.step.kind == NpcScheduleStep.Kind.ROUTE and not bool(resolved0.step.loop_route):
		var next_idx := ScheduleResolver.get_next_step_index(cfg0.schedule, resolved0.step_index)
		if next_idx >= 0:
			var next_step := cfg0.schedule.steps[next_idx]
			if (
				next_step != null
				and next_step.kind == NpcScheduleStep.Kind.ROUTE
				and next_step.route_res != null
			):
				var route_key := StringName("route:" + String(next_step.route_res.resource_path))
				var waypoints := _get_route_waypoints(next_step.route_res)
				var loop := bool(next_step.loop_route)
				tracker.set_route(
					route_key, waypoints, rec0.last_world_pos, rec0.current_level_id, loop, false
				)

				if tracker.is_active():
					var target := tracker.get_current_target()
					if target != null:
						order.facing_dir = next_step.facing_dir
						order.action = AgentOrder.Action.MOVE_TO
						order.target_position = target.position
						order.is_on_route = true
						order.route_key = route_key
						order.route_progress = tracker.get_progress()
						# If we chained early (before the next step's scheduled start),
						# keep executing that next ROUTE until the schedule catches up.
						var next_start := int(next_step.start_minute_of_day)
						if minute < next_start:
							_set_schedule_override(agent_id, next_idx, next_start)


func _ensure_tracker(agent_id: StringName) -> AgentRouteTracker:
	var tracker: AgentRouteTracker = _trackers.get(agent_id) as AgentRouteTracker
	if tracker == null:
		tracker = AgentRouteTracker.new()
		tracker.agent_id = agent_id
		_trackers[agent_id] = tracker
	return tracker


func debug_get_schedule_override_info(agent_id: StringName) -> Dictionary:
	# Used by debug HUD (best-effort).
	if not _schedule_override_step_idx.has(agent_id):
		return {}
	return {
		"step_index": int(_schedule_override_step_idx.get(agent_id, -1)),
		"expire_minute": int(_schedule_override_expire_minute.get(agent_id, -1)),
	}


func _set_schedule_override(agent_id: StringName, step_index: int, expire_minute: int) -> void:
	_schedule_override_step_idx[agent_id] = int(step_index)
	_schedule_override_expire_minute[agent_id] = int(expire_minute)


func _clear_schedule_override(agent_id: StringName) -> void:
	_schedule_override_step_idx.erase(agent_id)
	_schedule_override_expire_minute.erase(agent_id)


func _apply_schedule_override(
	agent_id: StringName,
	schedule: NpcSchedule,
	minute_of_day: int,
	resolved: ScheduleResolver.Resolved
) -> void:
	if schedule == null or resolved == null:
		return
	if not _schedule_override_step_idx.has(agent_id):
		return

	var idx := int(_schedule_override_step_idx.get(agent_id, -1))
	var expire := int(_schedule_override_expire_minute.get(agent_id, -1))

	# Expired or already caught up: clear.
	if expire >= 0 and minute_of_day >= expire:
		_clear_schedule_override(agent_id)
		return
	if resolved.step_index == idx:
		_clear_schedule_override(agent_id)
		return

	if idx < 0 or idx >= schedule.steps.size():
		_clear_schedule_override(agent_id)
		return

	var step := schedule.steps[idx]
	if step == null or not step.is_valid():
		_clear_schedule_override(agent_id)
		return

	resolved.step = step
	resolved.step_index = idx


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
		_:
			# If we entered HOLD but are still finishing a non-loop ROUTE,
			# keep walking/teleporting until the HOLD ends (lenient route completion).
			if (
				tracker != null
				and tracker.is_active()
				and not tracker.is_looping
				and not tracker.is_travel_route
			):
				var target := tracker.get_current_target()

				# If the next target is in another level, teleport and advance immediately,
				# so we continue toward the next waypoint during HOLD (not just stop).
				var guard := 0
				while (
					target != null
					and guard < 16
					and target.level_id != Enums.Levels.NONE
					and target.level_id != rec.current_level_id
				):
					var sp := SpawnPointData.new()
					sp.level_id = target.level_id
					sp.position = target.position
					commit_travel_and_sync(rec.agent_id, sp)
					# Keep local record consistent for this tick.
					rec.current_level_id = target.level_id
					rec.last_world_pos = target.position

					# We effectively arrived at this waypoint, so advance to the next one.
					target = tracker.advance()
					guard += 1

				# Now target is either null (route complete) or in our current level.
				if target != null and target.level_id == rec.current_level_id:
					order.action = AgentOrder.Action.MOVE_TO
					order.target_position = target.position
					order.is_on_route = true
					order.route_key = tracker.route_key
					order.route_progress = tracker.get_progress()
				else:
					order.action = AgentOrder.Action.IDLE
			else:
				order.action = AgentOrder.Action.IDLE

	return order


func _apply_route_step(
	order: AgentOrder, rec: AgentRecord, tracker: AgentRouteTracker, step: NpcScheduleStep
) -> void:
	var route: RouteResource = step.route_res
	if route == null:
		order.action = AgentOrder.Action.IDLE
		return

	var route_key := StringName("route:" + String(route.resource_path))
	var waypoints := _get_route_waypoints(route)
	var loop := bool(step.loop_route)

	tracker.set_route(route_key, waypoints, rec.last_world_pos, rec.current_level_id, loop, false)

	if not tracker.is_active():
		order.action = AgentOrder.Action.IDLE
		return

	var target := tracker.get_current_target()
	if target == null:
		order.action = AgentOrder.Action.IDLE
		return

	order.action = AgentOrder.Action.MOVE_TO
	order.target_position = target.position
	order.is_on_route = true
	order.route_key = route_key
	order.route_progress = tracker.get_progress()


func _get_route_waypoints(route: RouteResource) -> Array[WorldPoint]:
	var out: Array[WorldPoint] = []
	if route == null:
		return out

	return route.waypoints

#endregion
