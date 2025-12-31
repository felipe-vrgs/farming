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

static func simulate_minute(_day_index: int, minute_of_day: int) -> bool:
	# Returns true if active level should re-sync agents (e.g. an NPC traveled into it).
	if AgentRegistry == null or AgentSpawner == null or GameManager == null:
		return false

	var active_level_id: Enums.Levels = GameManager.get_active_level_id()
	var spawned: Dictionary = {} # StringName -> true
	for id in AgentSpawner.get_spawned_agent_ids():
		spawned[id] = true

	var needs_sync := false
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
				# Ensure record level matches where the schedule says the NPC should be.
				if (
					resolved.step.level_id != Enums.Levels.NONE
					and rec.current_level_id != resolved.step.level_id
				):
					rec.current_level_id = resolved.step.level_id
					AgentRegistry.upsert_record(rec)
					if rec.current_level_id == active_level_id:
						needs_sync = true
			NpcScheduleStep.Kind.TRAVEL:
				if resolved.step.target_level_id == Enums.Levels.NONE:
					continue
				# Commit travel even if NPC is unloaded.
				# If they enter the active level as a result, ask for a re-sync.
				if AgentRegistry.commit_travel_by_id(
					rec.agent_id,
					resolved.step.target_level_id,
					resolved.step.target_spawn_id
				):
					if resolved.step.target_level_id == active_level_id:
						needs_sync = true
			_:
				# HOLD: do nothing (keep record as-is).
				pass

	return needs_sync

