extends Node

## AgentRegistry - authoritative store for agent state across levels.
##
## Architecture principle: "Only TRAVEL commits change levels"
## ─────────────────────────────────────────────────────────────
## `current_level_id` is ONLY modified by `commit_travel_by_id()`.
## This function is called by:
##   - TravelZone (online NPC walks into portal)
##   - OfflineAgentSimulation (offline NPC reaches portal in simulation)
##   - Deadline commit (NPC got blocked, force-commit at step end)
##
## NO other system should modify `current_level_id`. This prevents:
##   - Race conditions between movement capture and travel commit
##   - Offline sim ROUTE steps overwriting committed travel
##   - Accidental level resets from stale schedule data
##
## Persistence:
##   - load_from_session() is called ONCE at game start (NewGame/Continue)
##   - save_to_session() is called periodically and after travel commits
##   - NO system reloads from disk during normal gameplay
##
const _OFFLINE_AGENT_SIM := preload("res://world/simulation/offline_agent_simulation.gd")

# Prevent immediate travel re-triggering after a commit (spawn overlap bounce).
# Key: agent_id, Value: ignore-until timestamp (msec).
const _TRAVEL_COOLDOWN_MSEC := 1000

## StringName agent_id -> AgentRecord
var _agents: Dictionary = {}
var _runtime_capture_enabled: bool = true
var _travel_cooldown_until_msec: Dictionary = {} # StringName -> int

func is_travel_allowed_now(agent_id: StringName) -> bool:
	if String(agent_id).is_empty():
		return true
	var now := Time.get_ticks_msec()
	var until_v = _travel_cooldown_until_msec.get(agent_id, -1)
	if typeof(until_v) == TYPE_INT and int(until_v) > int(now):
		return false
	return true

func _ready() -> void:
	set_process(false)
	if EventBus != null:
		EventBus.occupant_moved_to_cell.connect(_on_occupant_moved_to_cell)
	if TimeManager != null:
		TimeManager.time_changed.connect(_on_time_changed)

func _on_time_changed(day_index: int, minute_of_day: int, _day_progress: float) -> void:
	var needs_sync := false
	var did_mutate := false
	var active_level_id: Enums.Levels = _get_active_level_id()
	var deadline_committed: Dictionary = {} # StringName -> true

	# 1) TravelIntent deadlines: if a travel is pending and its deadline passes, force-commit.
	# This handles the "NPC got blocked and missed the portal" corner case.
	if TimeManager != null:
		var now_abs := int(TimeManager.get_absolute_minute())
		for rec in list_records():
			if rec == null:
				continue
			if rec.pending_level_id == Enums.Levels.NONE:
				continue
			if rec.pending_expires_absolute_minute < 0:
				continue
			if now_abs < rec.pending_expires_absolute_minute:
				continue

			var from_level := rec.current_level_id
			var ok := commit_travel_by_id(rec.agent_id, rec.pending_level_id, rec.pending_spawn_id)
			if not ok:
				continue
			did_mutate = true
			deadline_committed[rec.agent_id] = true
			if from_level == active_level_id or rec.current_level_id == active_level_id:
				needs_sync = true

	# 2) Offline sim (v1): update agent records for NPCs not currently spawned.
	# Only resync active level when an NPC traveled into it.
	# IMPORTANT: if we deadline-committed travel above, skip simulating those agents this tick.
	# Otherwise offline sim can overwrite the newly committed travel state
	# before the agent materializes in the destination level.
	var sim := _OFFLINE_AGENT_SIM.simulate_minute(day_index, minute_of_day, deadline_committed)
	if sim != null:
		if bool(sim.did_mutate):
			did_mutate = true
		if bool(sim.needs_sync):
			needs_sync = true

	if did_mutate:
		save_to_session()
	if needs_sync and AgentSpawner != null:
		AgentSpawner.sync_agents_for_active_level()

func load_from_session() -> void:
	if SaveManager == null:
		return
	# Always clear first so loading a slot/session fully overwrites runtime state.
	# If the file is missing/corrupt, we treat it as "no agents" rather than keeping stale data.
	_agents.clear()
	var a := SaveManager.load_session_agents_save()
	if a == null:
		return
	for rec in a.agents:
		if rec == null:
			continue
		if not rec.is_valid():
			continue
		_agents[rec.agent_id] = rec

func save_to_session() -> bool:
	if SaveManager == null:
		return false
	var a := AgentsSave.new()
	a.version = 1
	var list: Array[AgentRecord] = []
	for rec in _agents.values():
		if rec is AgentRecord and (rec as AgentRecord).is_valid():
			list.append(rec as AgentRecord)
	list.sort_custom(func(x: AgentRecord, y: AgentRecord) -> bool:
		return String(x.agent_id) < String(y.agent_id)
	)
	a.agents = list
	return SaveManager.save_session_agents_save(a)

func set_runtime_capture_enabled(enabled: bool) -> void:
	_runtime_capture_enabled = enabled

func apply_record_to_node(agent: Node, apply_position: bool = true) -> void:
	var rec: AgentRecord = ensure_agent_registered_from_node(agent) as AgentRecord
	if rec == null:
		return

	var ac := ComponentFinder.find_component_in_group(agent, Groups.AGENT_COMPONENTS)
	if ac is AgentComponent:
		(ac as AgentComponent).apply_record(rec, apply_position)

func capture_record_from_node(agent: Node) -> void:
	var rec: AgentRecord = ensure_agent_registered_from_node(agent) as AgentRecord
	if rec == null:
		return

	var ac := ComponentFinder.find_component_in_group(agent, Groups.AGENT_COMPONENTS)
	if ac is AgentComponent:
		(ac as AgentComponent).capture_into_record(rec)
		_agents[rec.agent_id] = rec

func get_record(agent_id: StringName):
	return _agents.get(agent_id)

func list_records() -> Array[AgentRecord]:
	var out: Array[AgentRecord] = []
	for rec in _agents.values():
		if rec is AgentRecord and (rec as AgentRecord).is_valid():
			out.append(rec as AgentRecord)
	return out

func upsert_record(rec):
	if rec == null or String(rec.agent_id).is_empty():
		return null
	_agents[rec.agent_id] = rec
	return rec

func ensure_agent_registered_from_node(agent: Node):
	if agent == null:
		return null
	var ac := ComponentFinder.find_component_in_group(agent, Groups.AGENT_COMPONENTS)
	if not (ac is AgentComponent):
		return null

	var agent_id: StringName = (ac as AgentComponent).agent_id
	if String(agent_id).is_empty():
		# Fallback: stable within this run only (better than empty).
		agent_id = StringName("agent_%d" % int(agent.get_instance_id()))

	var rec: AgentRecord = get_record(agent_id) as AgentRecord
	var is_new := false
	if rec == null:
		rec = AgentRecord.new()
		rec.agent_id = agent_id
		is_new = true

	rec.kind = (ac as AgentComponent).kind
	# Only stamp current_level_id on first registration.
	# If you overwrite it here every time, you can accidentally undo committed travel.
	if is_new:
		rec.current_level_id = _get_active_level_id()
	_agents[agent_id] = rec
	return rec


## TravelIntent: queue travel for an agent id.
func set_travel_intent_by_id(
	agent_id: StringName,
	target_level_id: Enums.Levels,
	target_spawn_id: Enums.SpawnId,
	expires_absolute_minute: int = -1
) -> bool:
	if String(agent_id).is_empty():
		return false
	var rec: AgentRecord = get_record(agent_id) as AgentRecord
	if rec == null:
		rec = AgentRecord.new()
		rec.agent_id = agent_id

	rec.pending_level_id = target_level_id
	rec.pending_spawn_id = target_spawn_id
	rec.pending_expires_absolute_minute = int(expires_absolute_minute)
	_agents[agent_id] = rec
	return true

## THE ONLY function that modifies current_level_id.
## Called by: TravelZone, OfflineAgentSimulation, deadline commit.
## Idempotent: safe to call multiple times with same args.
func commit_travel_by_id(
	agent_id: StringName,
	target_level_id: Enums.Levels,
	target_spawn_id: Enums.SpawnId
) -> bool:
	if String(agent_id).is_empty():
		return false
	var rec: AgentRecord = get_record(agent_id) as AgentRecord
	if rec == null:
		rec = AgentRecord.new()
		rec.agent_id = agent_id
	_agents[agent_id] = rec

	rec.current_level_id = target_level_id
	rec.last_spawn_id = target_spawn_id
	# Force spawn-marker placement on next materialization in the target level.
	# (We intentionally do NOT overwrite last_world_pos; that avoids (0,0) flashes.)
	rec.needs_spawn_marker = true
	_travel_cooldown_until_msec[rec.agent_id] = int(Time.get_ticks_msec() + _TRAVEL_COOLDOWN_MSEC)
	# Clear pending intent now that travel is committed.
	rec.pending_level_id = Enums.Levels.NONE
	rec.pending_spawn_id = Enums.SpawnId.NONE
	rec.pending_expires_absolute_minute = -1
	_agents[agent_id] = rec
	return true

## Convenience API for runtime systems:
## commit travel + persist + sync spawned agents for active level.
func commit_travel_and_sync(
	agent_id: StringName,
	target_level_id: Enums.Levels,
	target_spawn_id: Enums.SpawnId
) -> bool:
	var ok := commit_travel_by_id(agent_id, target_level_id, target_spawn_id)
	if not ok:
		return false
	save_to_session()
	if AgentSpawner != null:
		AgentSpawner.sync_agents_for_active_level()
	return true

func _on_occupant_moved_to_cell(entity: Node, cell: Vector2i, world_pos: Vector2) -> void:
	if not _runtime_capture_enabled:
		return
	var rec: AgentRecord = ensure_agent_registered_from_node(entity) as AgentRecord
	if rec == null:
		return

	# If travel has already been committed to a different level, ignore further movement captures
	# coming from the old level during the despawn frame(s).
	var active_level_id: Enums.Levels = _get_active_level_id()
	if (
		rec.current_level_id != Enums.Levels.NONE
		and rec.current_level_id != active_level_id
	):
		return

	# Update position only. current_level_id is ONLY changed by commit_travel_by_id().
	rec.last_cell = cell
	rec.last_world_pos = world_pos
	_agents[rec.agent_id] = rec

func debug_get_agents() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	return _agents

func _get_active_level_id() -> Enums.Levels:
	if GameManager != null:
		return GameManager.get_active_level_id()
	return Enums.Levels.NONE
