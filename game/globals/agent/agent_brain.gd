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

## Per-agent IDLE_AROUND state.
## StringName agent_id -> _IdleAroundState
var _idle_around_state: Dictionary = {}


class _IdleAroundState:
	extends RefCounted
	var step_key: StringName = &""
	var point_index: int = 0
	var pending_index: int = -1
	var hold_until_abs_minute: int = -1


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


## Hard reset for a fresh session/new game.
## Autoloads persist across "Quit to Menu", so we must clear in-memory state explicitly.
func reset_for_new_game() -> void:
	_orders.clear()
	_trackers.clear()
	_statuses.clear()
	_schedule_override_step_idx.clear()
	_schedule_override_expire_minute.clear()
	_idle_around_state.clear()

	active_level_id = Enums.Levels.NONE

	if spawner != null and spawner.has_method("despawn_all"):
		spawner.call("despawn_all")

	# Clear all agent records; they will be re-seeded after new game hydrate.
	if registry != null:
		registry.load_from_session(null)


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
	var abs_minute := TimeManager.get_absolute_minute() if TimeManager != null else 0

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

		var order := _compute_order(rec, cfg, tracker, resolved, minute_of_day, abs_minute)
		_orders[rec.agent_id] = order

		if not is_online:
			var speed := cfg.move_speed if cfg != null and cfg.move_speed > 0.0 else 22.0
			var result := AgentOfflineSim.apply_order(rec, order, tracker, speed, registry)
			if result.changed:
				did_mutate = true
			if result.committed_travel and rec.current_level_id == active_level_id:
				needs_sync = true
			if result.reached_target:
				_on_agent_reached_target(rec.agent_id)

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
		# Avoid calling get_tree() when running outside a SceneTree (some headless tests).
		if is_inside_tree():
			var lr = _get_active_level_root()
			if lr != null:
				spawner.sync_agents_for_active_level(lr)
	return true


func _get_active_level_root() -> LevelRoot:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var scene := tree.current_scene
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
			NpcScheduleStep.Kind.IDLE_AROUND:
				# Place at the first valid idle point.
				rec.last_spawn_point_path = ""
				rec.needs_spawn_marker = false
				rec.last_cell = Vector2i(-1, -1)

				var sp_target: SpawnPointData = null
				if step is NpcScheduleStep:
					for p in (step as NpcScheduleStep).idle_points:
						if p != null and p.is_valid():
							sp_target = p.spawn_point
							break
				if sp_target == null or not sp_target.is_valid():
					continue

				rec.current_level_id = sp_target.level_id
				rec.last_world_pos = sp_target.position
				registry.upsert_record(rec)
				did_mutate = true
			_:
				# HOLD (or unknown): snap to the step's hold spawn point (preferred),
				# otherwise fall back to the NPC initial spawn point (legacy).
				rec.last_spawn_point_path = ""
				rec.needs_spawn_marker = false
				rec.last_cell = Vector2i(-1, -1)

				var sp_target: SpawnPointData = null
				if step is NpcScheduleStep and (step as NpcScheduleStep).hold_spawn_point != null:
					sp_target = (step as NpcScheduleStep).hold_spawn_point
				elif cfg.initial_spawn_point != null and cfg.initial_spawn_point.is_valid():
					sp_target = cfg.initial_spawn_point

				if sp_target == null or not sp_target.is_valid():
					continue

				rec.current_level_id = sp_target.level_id
				rec.last_world_pos = sp_target.position
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

			# Also re-apply the updated records to already-spawned NPC nodes in this level.
			# (Spawner sync only spawns/despawns; it doesn't reposition existing nodes.)
			for rec2 in registry.list_records():
				if rec2 == null or rec2.kind != Enums.AgentKind.NPC:
					continue
				if rec2.current_level_id != lr.level_id:
					continue
				var n := spawner.get_agent_node(rec2.agent_id)
				if n != null and is_instance_valid(n):
					registry.apply_record_to_node(n, true)


#endregion

#endregion

#region Internal

const _HOLD_POS_EPS := 2.0
const _REACHED_GUARD_EPS := 12.0  # pixels; matches online NPC waypoint tolerance (~8px) with slack.


func _on_agent_reached_target(agent_id: StringName) -> void:
	if _check_if_idle_around_reached(agent_id):
		return

	var tracker: AgentRouteTracker = _trackers.get(agent_id) as AgentRouteTracker
	if tracker == null or not tracker.is_active():
		return

	var order: AgentOrder = _orders.get(agent_id) as AgentOrder
	if order == null:
		return

	# Defensive: only advance the route if the "reached" report matches the current target.
	# This prevents desyncs (e.g. if an agent spawns already at a previous waypoint but the
	# tracker has advanced, or vice-versa).
	var st := _statuses.get(agent_id) as AgentStatus
	if st != null:
		var wp := tracker.get_current_target()
		if wp != null and wp.level_id == active_level_id:
			var d2 := st.position.distance_squared_to(wp.position)
			if d2 > (_REACHED_GUARD_EPS * _REACHED_GUARD_EPS):
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


func _check_if_idle_around_reached(agent_id: StringName) -> bool:
	if registry == null or spawner == null or TimeManager == null:
		return false

	var rec0 := registry.get_record(agent_id) as AgentRecord
	var cfg0: NpcConfig = spawner.get_npc_config(agent_id)
	if rec0 == null or cfg0 == null or cfg0.schedule == null:
		return false

	var minute := int(TimeManager.get_minute_of_day())
	var abs_minute := int(TimeManager.get_absolute_minute())
	var resolved0 := ScheduleResolver.resolve(cfg0.schedule, minute)
	_apply_schedule_override(agent_id, cfg0.schedule, minute, resolved0)
	if resolved0 == null or resolved0.step == null:
		return false

	# IDLE_AROUND reached: start hold + queue next point selection.
	if resolved0.step.kind == NpcScheduleStep.Kind.IDLE_AROUND:
		_on_idle_around_reached(agent_id, resolved0.step, resolved0.step_index, abs_minute)
		return true

	return false


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
	_apply_schedule_override(agent_id, cfg0.schedule, minute, resolved0)
	if resolved0 == null or resolved0.step == null:
		return

	# Only chain if explicitly enabled on this step.
	if (
		resolved0.step.kind == NpcScheduleStep.Kind.ROUTE
		and bool(resolved0.step.chain_next_route)
		and not bool(resolved0.step.loop_route)
	):
		var next_idx := ScheduleResolver.get_next_step_index(cfg0.schedule, resolved0.step_index)
		if next_idx >= 0:
			var next_step := cfg0.schedule.steps[next_idx]
			if (
				next_step != null
				and next_step.kind == NpcScheduleStep.Kind.ROUTE
				and next_step.route_res != null
			):
				var base_route_key := StringName(
					"route:" + String(next_step.route_res.resource_path)
				)
				var mins_per_day := 1440
				if TimeManager != null and int(TimeManager.MINUTES_PER_DAY) > 0:
					mins_per_day = int(TimeManager.MINUTES_PER_DAY)
				var abs_minute := int(TimeManager.get_absolute_minute())
				var day := int(abs_minute / mins_per_day)
				var route_instance_key := StringName(
					(
						"route:%s:%d:%d"
						% [String(next_step.route_res.resource_path), day, int(next_idx)]
					)
				)
				var waypoints := _get_route_waypoints(next_step.route_res)
				var loop := bool(next_step.loop_route)
				tracker.set_route(
					base_route_key,
					waypoints,
					rec0.last_world_pos,
					rec0.current_level_id,
					loop,
					false,
					route_instance_key
				)

				if tracker.is_active():
					var target := tracker.get_current_target()
					if target != null:
						order.facing_dir = next_step.facing_dir
						order.action = AgentOrder.Action.MOVE_TO
						order.target_position = target.position
						order.is_on_route = true
						order.route_key = base_route_key
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
	resolved: ScheduleResolver.Resolved,
	minute_of_day: int = -1,
	abs_minute: int = -1
) -> AgentOrder:
	var order := AgentOrder.new()
	order.agent_id = rec.agent_id

	# Backwards-compatible defaults for tests/older call sites.
	if minute_of_day < 0:
		minute_of_day = int(TimeManager.get_minute_of_day()) if TimeManager != null else 0
	if abs_minute < 0:
		abs_minute = int(TimeManager.get_absolute_minute()) if TimeManager != null else 0

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
			_apply_route_step(order, rec, tracker, resolved.step, resolved.step_index, abs_minute)
		NpcScheduleStep.Kind.IDLE_AROUND:
			_apply_idle_around_step(
				order, rec, resolved.step, resolved.step_index, minute_of_day, abs_minute
			)
		_:
			# HOLD: snap/teleport to the configured spawn point (simplifies schedule behavior).
			order.action = AgentOrder.Action.IDLE

			# Stop any previous route tracking when HOLD is active.
			if tracker != null and tracker.is_active():
				tracker.reset()

			var step := resolved.step
			var sp_target: SpawnPointData = null
			if step is NpcScheduleStep and (step as NpcScheduleStep).hold_spawn_point != null:
				sp_target = (step as NpcScheduleStep).hold_spawn_point
			elif (
				cfg != null
				and cfg.initial_spawn_point != null
				and cfg.initial_spawn_point.is_valid()
			):
				# Legacy fallback.
				sp_target = cfg.initial_spawn_point

			if sp_target == null or not sp_target.is_valid():
				return order

			var needs_teleport := rec.current_level_id != sp_target.level_id
			if not needs_teleport:
				var d2 := rec.last_world_pos.distance_squared_to(sp_target.position)
				needs_teleport = d2 > (_HOLD_POS_EPS * _HOLD_POS_EPS)

			if needs_teleport:
				commit_travel_and_sync(rec.agent_id, sp_target)
				# Keep local record consistent for this tick (best-effort).
				rec.current_level_id = sp_target.level_id
				rec.last_world_pos = sp_target.position
				# If the NPC is currently spawned, move it immediately so it doesn't appear frozen.
				if spawner != null:
					var node := spawner.get_agent_node(rec.agent_id)
					if node != null and is_instance_valid(node) and node is Node2D:
						(node as Node2D).global_position = sp_target.position

	return order


func _apply_idle_around_step(
	order: AgentOrder,
	rec: AgentRecord,
	step: NpcScheduleStep,
	step_index: int,
	_minute_of_day: int,
	abs_minute: int
) -> void:
	if order == null or rec == null or step == null:
		return
	if step.idle_points.is_empty():
		order.action = AgentOrder.Action.IDLE
		return

	var st := _ensure_idle_around_state(rec.agent_id)
	var step_key := StringName("%d:%d" % [int(step.get_instance_id()), int(step_index)])
	if st.step_key != step_key:
		st.step_key = step_key
		st.pending_index = -1
		st.hold_until_abs_minute = -1
		st.point_index = _pick_idle_around_initial_index(step, rec)

	# Apply pending switch when hold window ends.
	if st.hold_until_abs_minute >= 0 and abs_minute >= st.hold_until_abs_minute:
		st.hold_until_abs_minute = -1
		if st.pending_index >= 0:
			st.point_index = st.pending_index
			st.pending_index = -1

	var p := _get_idle_around_point(step, st.point_index)
	if p == null:
		order.action = AgentOrder.Action.IDLE
		return

	var sp := p.spawn_point
	if sp == null or not sp.is_valid():
		order.action = AgentOrder.Action.IDLE
		return

	order.facing_dir = p.facing_dir

	# If the point is in another level, teleport to it (idle-around is local behavior).
	if rec.current_level_id != sp.level_id:
		commit_travel_and_sync(rec.agent_id, sp)
		rec.current_level_id = sp.level_id
		rec.last_world_pos = sp.position

	# If currently holding at this point, stay idle.
	if st.hold_until_abs_minute >= 0 and abs_minute < st.hold_until_abs_minute:
		order.action = AgentOrder.Action.IDLE
		return

	# If already at target (offline or freshly teleported), treat as reached and begin hold.
	var d2 := rec.last_world_pos.distance_squared_to(sp.position)
	if d2 <= (_HOLD_POS_EPS * _HOLD_POS_EPS):
		_on_idle_around_reached(rec.agent_id, step, step_index, abs_minute)
		order.action = AgentOrder.Action.IDLE
		return

	order.action = AgentOrder.Action.MOVE_TO
	order.target_position = sp.position


func _ensure_idle_around_state(agent_id: StringName) -> _IdleAroundState:
	var st := _idle_around_state.get(agent_id) as _IdleAroundState
	if st == null:
		st = _IdleAroundState.new()
		_idle_around_state[agent_id] = st
	return st


func _pick_idle_around_initial_index(step: NpcScheduleStep, rec: AgentRecord) -> int:
	if step == null or rec == null or step.idle_points.is_empty():
		return 0

	# Deterministic mode: always start from the first valid point (index order),
	# so designers can control the path by list ordering.
	if not bool(step.idle_random):
		for i0 in range(step.idle_points.size()):
			var p0 := step.idle_points[i0]
			if p0 != null and p0.is_valid():
				return i0
		return 0

	# Random mode: choose a valid point in the current level when possible.
	var valid_same_level: Array[int] = []
	for i0 in range(step.idle_points.size()):
		var p0 := step.idle_points[i0]
		if p0 == null or not p0.is_valid():
			continue
		if p0.spawn_point.level_id == rec.current_level_id:
			valid_same_level.append(i0)
	if not valid_same_level.is_empty():
		return valid_same_level[randi() % valid_same_level.size()]

	var best_i := 0
	var best_d2 := INF
	for i in range(step.idle_points.size()):
		var p := step.idle_points[i]
		if p == null or not p.is_valid():
			continue
		if p.spawn_point.level_id != rec.current_level_id:
			continue
		var d2 := rec.last_world_pos.distance_squared_to(p.spawn_point.position)
		if d2 < best_d2:
			best_d2 = d2
			best_i = i

	# Fallback to the first valid point.
	if best_d2 == INF:
		for i2 in range(step.idle_points.size()):
			var p2 := step.idle_points[i2]
			if p2 != null and p2.is_valid():
				return i2
		best_i = 0
	return best_i


func _get_idle_around_point(step: NpcScheduleStep, idx: int) -> NpcIdleAroundPoint:
	if step == null or step.idle_points.is_empty():
		return null
	var i := clampi(idx, 0, step.idle_points.size() - 1)
	var p := step.idle_points[i]
	if p != null and p.is_valid():
		return p
	# Try to find any valid point.
	for p2 in step.idle_points:
		if p2 != null and p2.is_valid():
			return p2
	return null


func _pick_idle_around_next_index(step: NpcScheduleStep, current_idx: int) -> int:
	if step == null or step.idle_points.is_empty():
		return -1
	var n := step.idle_points.size()
	if n <= 1:
		return current_idx

	if not bool(step.idle_random):
		return (current_idx + 1) % n

	# Random: avoid repeating the same point when possible.
	var tries := 0
	while tries < 8:
		var r := randi() % n
		if r != current_idx:
			return r
		tries += 1
	return (current_idx + 1) % n


func _on_idle_around_reached(
	agent_id: StringName, step: NpcScheduleStep, step_index: int, abs_minute: int
) -> void:
	if step == null or step.idle_points.is_empty():
		return
	var st := _ensure_idle_around_state(agent_id)
	var step_key := StringName("%d:%d" % [int(step.get_instance_id()), int(step_index)])
	if st.step_key != step_key:
		st.step_key = step_key
		st.point_index = 0
		st.pending_index = -1
		st.hold_until_abs_minute = -1

	var p := _get_idle_around_point(step, st.point_index)
	if p == null:
		return

	# Start hold now and queue next index for when hold ends.
	var hold = max(0, int(p.hold_minutes))
	if hold > 0:
		st.hold_until_abs_minute = abs_minute + hold
	else:
		st.hold_until_abs_minute = abs_minute
	st.pending_index = _pick_idle_around_next_index(step, st.point_index)


func _apply_route_step(
	order: AgentOrder,
	rec: AgentRecord,
	tracker: AgentRouteTracker,
	step: NpcScheduleStep,
	step_index: int,
	abs_minute: int
) -> void:
	var route: RouteResource = step.route_res
	if route == null:
		order.action = AgentOrder.Action.IDLE
		return

	# Include day + step index so:
	# - completed non-looping routes don't restart every tick within the same step
	# - the same route resource can be re-used by multiple steps
	# - routes restart correctly on a new day even if the schedule step spans all day
	var mins_per_day := 1440
	if TimeManager != null and int(TimeManager.MINUTES_PER_DAY) > 0:
		mins_per_day = int(TimeManager.MINUTES_PER_DAY)
	var day := int(abs_minute / mins_per_day)

	var base_route_key := StringName("route:" + String(route.resource_path))
	var route_instance_key := StringName(
		"route:%s:%d:%d" % [String(route.resource_path), day, int(step_index)]
	)
	var waypoints := _get_route_waypoints(route)
	var loop := bool(step.loop_route)

	tracker.set_route(
		base_route_key,
		waypoints,
		rec.last_world_pos,
		rec.current_level_id,
		loop,
		false,
		route_instance_key
	)

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
	order.route_key = base_route_key
	order.route_progress = tracker.get_progress()


func _get_route_waypoints(route: RouteResource) -> Array[WorldPoint]:
	var out: Array[WorldPoint] = []
	if route == null:
		return out

	# Return a copy so callers can't accidentally mutate the resource array.
	return route.waypoints.duplicate()

#endregion
