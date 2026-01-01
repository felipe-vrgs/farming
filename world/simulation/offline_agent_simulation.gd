class_name OfflineAgentSimulation
extends Object

## Offline NPC schedule simulation.
##
## Architecture principle: "Only TRAVEL commits change levels"
## ─────────────────────────────────────────────────────────────
## - `current_level_id` is ONLY changed by `AgentRegistry.commit_travel_by_id()`.
## - ROUTE steps NEVER change levels. If the agent isn't in the route's level, they hold.
## - TRAVEL steps walk the exit route, then commit when the portal is reached.
## - This ensures online (spawned NPC) and offline (this sim) behave identically.
##
## Step behavior:
## - ROUTE: Move along route IF agent is in the route's level. Otherwise hold position.
## - TRAVEL: Walk exit route toward portal. Commit travel when reached. No-op after commit.
## - HOLD: Do nothing.
##
## Notes:
## - Spawned NPCs are excluded; their runtime `NpcScheduleResolver` drives them.
## - This runs on TimeManager minute ticks (see AgentRegistry).

const _MINUTES_PER_DAY := 24 * 60
const _TRAVEL_REACH_EPS := 2.0
const _TRAVEL_SPAWN_MARGIN := 6.0

class Result:
	var did_mutate: bool = false
	var needs_sync: bool = false

const _SIM_NONE := 0
const _SIM_CHANGED := 1
const _SIM_COMMITTED_TRAVEL := 2

static func simulate_minute(
	_day_index: int,
	minute_of_day: int,
	skip_agent_ids: Dictionary = {}
) -> Result:
	# Returns a Result:
	# - did_mutate: any AgentRecord changed
	# - needs_sync: active level should re-sync agents (e.g. an NPC traveled into it)
	var out := Result.new()
	if AgentRegistry == null or AgentSpawner == null or GameManager == null:
		return out

	var active_level_id: Enums.Levels = GameManager.get_active_level_id()
	var spawned: Dictionary = {} # StringName -> true
	for id in AgentSpawner.get_spawned_agent_ids():
		spawned[id] = true

	var now_abs := int(TimeManager.get_absolute_minute()) if TimeManager != null else -1

	for rec in AgentRegistry.list_records():
		if rec == null:
			continue
		if rec.kind != Enums.AgentKind.NPC:
			continue
		if not skip_agent_ids.is_empty() and skip_agent_ids.has(rec.agent_id):
			continue
		if spawned.has(rec.agent_id):
			continue

		var cfg: NpcConfig = AgentSpawner.get_npc_config(rec.agent_id)
		if cfg == null or cfg.schedule == null:
			continue

		var delta := 1
		if now_abs >= 0 and int(rec.last_sim_absolute_minute) >= 0:
			delta = now_abs - int(rec.last_sim_absolute_minute)
		# If time jumped too far or backwards, reset to a single-step approximation.
		if delta <= 0 or delta > 180:
			delta = 1
			rec.last_sim_route_key = &""
			rec.last_sim_route_distance = 0.0

		var start_min := _normalize_minute(minute_of_day - (delta - 1))
		for i in range(delta):
			var m := _normalize_minute(start_min + i)
			var status := _simulate_agent_minute(rec, cfg, m)
			if status != _SIM_NONE:
				out.did_mutate = true
				if rec.current_level_id == active_level_id:
					out.needs_sync = true
			# If we committed travel, stop simulating further minutes for this agent in this tick.
			# Otherwise we can overwrite the "spawn-marker forced" position (Vector2.ZERO) and cause
			# confusing spawn placement in the destination level.
			if status == _SIM_COMMITTED_TRAVEL:
				break

		if now_abs >= 0:
			rec.last_sim_absolute_minute = now_abs
		AgentRegistry.upsert_record(rec)

	return out

static func _simulate_agent_minute(
	rec: AgentRecord,
	cfg: NpcConfig,
	minute_of_day: int
) -> int:
	if rec == null or cfg == null or cfg.schedule == null:
		return _SIM_NONE

	var resolved := NpcScheduleResolver.resolve(cfg.schedule, minute_of_day)
	if resolved == null or resolved.step == null:
		return _SIM_NONE

	var speed := float(cfg.move_speed) if cfg.move_speed > 0.0 else 22.0
	var step_dist := speed * _seconds_per_game_minute()
	var did_change := false

	match resolved.step.kind:
		NpcScheduleStep.Kind.ROUTE:
			# ROUTE steps NEVER change current_level_id.
			# If the agent isn't in the route's level (e.g., travel committed early),
			# they simply hold position until a TRAVEL step moves them.
			var route := resolved.step.route_res
			if route == null or not route.is_valid():
				return _SIM_NONE

			# If route specifies a level and agent isn't there, hold position.
			# This prevents overwriting a committed travel destination.
			if (
				resolved.step.level_id != Enums.Levels.NONE
				and rec.current_level_id != resolved.step.level_id
			):
				return _SIM_NONE

			var looped := bool(resolved.step.loop_route)
			var key := StringName("route:" + String(route.resource_path))
			if rec.last_sim_route_key != key:
				rec.last_sim_route_key = key
				rec.last_sim_route_distance = route.project_distance_world(rec.last_world_pos, looped)

			rec.last_sim_route_distance += step_dist
			var pos := route.sample_world_pos_by_distance(rec.last_sim_route_distance, looped)

			if rec.last_world_pos != pos:
				rec.last_world_pos = pos
				did_change = true
			return _SIM_CHANGED if did_change else _SIM_NONE

		NpcScheduleStep.Kind.TRAVEL:
			if resolved.step.target_level_id == Enums.Levels.NONE:
				return _SIM_CHANGED if did_change else _SIM_NONE

			# If travel has already been committed (agent is already in destination),
			# do nothing for the remainder of this TRAVEL step.
			# This mirrors online behavior and prevents repeated commits / position churn.
			if rec.current_level_id == resolved.step.target_level_id:
				if (
					rec.pending_level_id != Enums.Levels.NONE
					or rec.pending_spawn_id != Enums.SpawnId.NONE
					or int(rec.pending_expires_absolute_minute) != -1
				):
					rec.pending_level_id = Enums.Levels.NONE
					rec.pending_spawn_id = Enums.SpawnId.NONE
					rec.pending_expires_absolute_minute = -1
					did_change = true
				return _SIM_CHANGED if did_change else _SIM_NONE

			# Teleport-style travel.
			if resolved.step.exit_route_res == null:
				if AgentRegistry.commit_travel_by_id(
					rec.agent_id,
					resolved.step.target_level_id,
					resolved.step.target_spawn_id
				):
					rec.last_sim_route_key = &""
					rec.last_sim_route_distance = 0.0
					return _SIM_COMMITTED_TRAVEL
				return _SIM_CHANGED if did_change else _SIM_NONE

			# Walk-to-portal style travel (exit route).
			var exit_res := resolved.step.exit_route_res
			var target_pos := exit_res.sample_world_pos(1.0, false)
			var route_len := exit_res.get_length(false)

			if route_len > 0.0:
				var key := StringName("travel:" + String(exit_res.resource_path))
				if rec.last_sim_route_key != key:
					rec.last_sim_route_key = key
					rec.last_sim_route_distance = exit_res.project_distance_world(rec.last_world_pos, false)
				rec.last_sim_route_distance += step_dist

				# If reached (or almost reached), commit travel.
				if (route_len - rec.last_sim_route_distance) <= _TRAVEL_REACH_EPS:
					if AgentRegistry.commit_travel_by_id(
						rec.agent_id,
						resolved.step.target_level_id,
						resolved.step.target_spawn_id
					):
						rec.last_sim_route_key = &""
						rec.last_sim_route_distance = 0.0
						return _SIM_COMMITTED_TRAVEL
					return _SIM_CHANGED if did_change else _SIM_NONE

				# Otherwise keep them just before the portal.
				var clamp_dist: float = min(
					rec.last_sim_route_distance,
					max(0.0, route_len - _TRAVEL_SPAWN_MARGIN)
				)
				var pos: Vector2 = exit_res.sample_world_pos_by_distance(clamp_dist, false)

				if rec.last_world_pos != pos:
					rec.last_world_pos = pos
					did_change = true
			else:
				# Single-point exit: walk toward target in a straight line.
				var to_target := target_pos - rec.last_world_pos
				var d := to_target.length()
				if d <= _TRAVEL_REACH_EPS:
					if AgentRegistry.commit_travel_by_id(
						rec.agent_id,
						resolved.step.target_level_id,
						resolved.step.target_spawn_id
					):
						rec.last_sim_route_key = &""
						rec.last_sim_route_distance = 0.0
						return _SIM_COMMITTED_TRAVEL
					return _SIM_CHANGED if did_change else _SIM_NONE

				var step_move: float = min(step_dist, max(0.0, d - _TRAVEL_SPAWN_MARGIN))
				var pos: Vector2 = rec.last_world_pos + (to_target / d) * step_move
				if rec.last_world_pos != pos:
					rec.last_world_pos = pos
					did_change = true
				# Commit if we'd reach the portal this minute.
				if step_dist >= (d - _TRAVEL_REACH_EPS):
					if AgentRegistry.commit_travel_by_id(
						rec.agent_id,
						resolved.step.target_level_id,
						resolved.step.target_spawn_id
					):
						rec.last_sim_route_key = &""
						rec.last_sim_route_distance = 0.0
						return _SIM_COMMITTED_TRAVEL

			# Maintain TravelIntent deadline as online fallback, but don't override committed travel.
			if TimeManager != null and rec.current_level_id != resolved.step.target_level_id:
				var remaining := _get_step_remaining_minutes(minute_of_day, resolved.step)
				var expires_abs := int(TimeManager.get_absolute_minute()) + remaining
				# Set directly to avoid calling back into AgentRegistry every minute.
				if (
					rec.pending_level_id != resolved.step.target_level_id
					or rec.pending_spawn_id != resolved.step.target_spawn_id
					or int(rec.pending_expires_absolute_minute) != int(expires_abs)
				):
					rec.pending_level_id = resolved.step.target_level_id
					rec.pending_spawn_id = resolved.step.target_spawn_id
					rec.pending_expires_absolute_minute = int(expires_abs)
					did_change = true
			return _SIM_CHANGED if did_change else _SIM_NONE

		_:
			# HOLD: do nothing.
			pass

	return _SIM_CHANGED if did_change else _SIM_NONE

static func _normalize_minute(m: int) -> int:
	var mm := m % _MINUTES_PER_DAY
	if mm < 0:
		mm += _MINUTES_PER_DAY
	return mm

static func _seconds_per_game_minute() -> float:
	if TimeManager == null:
		return 0.0
	var mins := float(TimeManager.MINUTES_PER_DAY)
	if mins <= 0.0:
		mins = 1440.0
	var d := float(TimeManager.day_duration_seconds)
	if d <= 0.0:
		return 0.0
	return d / mins

static func _get_step_remaining_minutes(minute_of_day: int, step: NpcScheduleStep) -> int:
	var m := int(minute_of_day) % (24 * 60)
	if m < 0:
		m += (24 * 60)
	var start: int = clampi(step.start_minute_of_day, 0, (24 * 60) - 1)
	var end: int = start + max(1, step.duration_minutes)
	if end <= (24 * 60):
		return maxi(1, end - m)
	# Wrap case.
	var wrapped_end := end % (24 * 60)
	if m >= start:
		return maxi(1, end - m)
	return maxi(1, wrapped_end - m)

