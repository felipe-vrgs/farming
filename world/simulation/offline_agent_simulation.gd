class_name OfflineAgentSimulation
extends Object

## Offline NPC schedule simulation (v1).
##
## Goal (v1):
## - When an NPC's level is not loaded, still keep its AgentRecord consistent with the schedule.
## - Handle TRAVEL steps deterministically (commit travel even if NPC isn't spawned).
## - Do NOT attempt offline path following yet (no route position sampling in v1).
##
## Notes:
## - Spawned NPCs are excluded; their runtime `NpcScheduleResolver` drives them.
## - This runs on TimeManager minute ticks (see AgentRegistry).

class Result:
	var did_mutate: bool = false
	var needs_sync: bool = false

static func simulate_minute(_day_index: int, minute_of_day: int) -> Result:
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

	for rec in AgentRegistry.list_records():
		if rec == null:
			continue
		if rec.kind != Enums.AgentKind.NPC:
			continue
		if spawned.has(rec.agent_id):
			continue

		var cfg: NpcConfig = AgentSpawner.get_npc_config(rec.agent_id)
		if cfg == null or cfg.schedule == null:
			continue

		# Resolve schedule at the current minute. If no step matches, do nothing (treat as "hold").
		var resolved := NpcScheduleResolver.resolve(cfg.schedule, minute_of_day)
		if resolved == null or resolved.step == null:
			continue

		match resolved.step.kind:
			NpcScheduleStep.Kind.ROUTE:
				# Ensure record level + position match where the schedule says the NPC should be.
				var did_change := false

				if (
					resolved.step.level_id != Enums.Levels.NONE
					and rec.current_level_id != resolved.step.level_id
				):
					rec.current_level_id = resolved.step.level_id
					did_change = true

				var route := resolved.step.route_res
				if route != null and route.is_valid():
					var looped := bool(resolved.step.loop_route)
					var elapsed_m := float(resolved.progress) * float(max(1, resolved.step.duration_minutes))
					var speed := float(cfg.move_speed) if cfg.move_speed > 0.0 else 22.0
					var sec_per_game_min := _seconds_per_game_minute()
					var dist := elapsed_m * speed * sec_per_game_min
					var pos := route.sample_world_pos_by_distance(dist, looped)
					if rec.last_world_pos != pos:
						rec.last_world_pos = pos
						did_change = true

				if did_change:
					AgentRegistry.upsert_record(rec)
					out.did_mutate = true
					if rec.current_level_id == active_level_id:
						out.needs_sync = true
			NpcScheduleStep.Kind.TRAVEL:
				if resolved.step.target_level_id == Enums.Levels.NONE:
					continue
				if resolved.step.exit_route_res != null and TimeManager != null:
					# Approximate progress along the exit route while offline so spawning mid-window
					# places the NPC near where they'd be if they were loaded.
					var elapsed_m := float(resolved.progress) * float(max(1, resolved.step.duration_minutes))
					var speed := float(cfg.move_speed) if cfg.move_speed > 0.0 else 22.0
					var sec_per_game_min := _seconds_per_game_minute()
					var dist := elapsed_m * speed * sec_per_game_min
					var pos := resolved.step.exit_route_res.sample_world_pos_by_distance(dist, false)
					if rec.last_world_pos != pos:
						rec.last_world_pos = pos

					# If an exit route exists, treat TRAVEL as "takes time":
					# queue TravelIntent with a deadline, and only commit at/after deadline.
					var remaining := _get_step_remaining_minutes(minute_of_day, resolved.step)
					var expires_abs := int(TimeManager.get_absolute_minute()) + remaining
					AgentRegistry.set_travel_intent_by_id(
						rec.agent_id,
						resolved.step.target_level_id,
						resolved.step.target_spawn_id,
						expires_abs
					)
					out.did_mutate = true
					continue

				# No exit route: commit immediately (teleport-style).
				if AgentRegistry.commit_travel_by_id(
					rec.agent_id,
					resolved.step.target_level_id,
					resolved.step.target_spawn_id
				):
					if resolved.step.target_level_id == active_level_id:
						out.needs_sync = true
					out.did_mutate = true
			_:
				# HOLD: do nothing (keep record as-is).
				pass

	return out

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

