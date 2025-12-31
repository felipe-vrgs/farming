extends Node

## Global registry tracking agents across levels (player + NPCs).
## - NPCs can "travel" (schedule-driven) without forcing an active scene change.
## - Player travel is handled by GameManager; registry is updated for bookkeeping.
const _OFFLINE_AGENT_SIM := preload("res://world/simulation/offline_agent_simulation.gd")

## StringName agent_id -> AgentRecord
var _agents: Dictionary = {}
var _runtime_capture_enabled: bool = true

func _ready() -> void:
	set_process(false)
	if EventBus != null:
		EventBus.occupant_moved_to_cell.connect(_on_occupant_moved_to_cell)
	if TimeManager != null:
		TimeManager.time_changed.connect(_on_time_changed)

func _on_time_changed(day_index: int, minute_of_day: int, _day_progress: float) -> void:
	# Offline sim (v1): update agent records for NPCs not currently spawned.
	# Only resync active level when an NPC traveled into it.
	var needs_sync := _OFFLINE_AGENT_SIM.simulate_minute(day_index, minute_of_day)
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

func request_travel_by_node(
	agent: Node,
	target_level_id: Enums.Levels,
	target_spawn_id: Enums.SpawnId
) -> bool:
	var rec: AgentRecord = ensure_agent_registered_from_node(agent) as AgentRecord
	if rec == null:
		return false
	rec.pending_level_id = target_level_id
	rec.pending_spawn_id = target_spawn_id
	_agents[rec.agent_id] = rec
	return true

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
	# Otherwise, the spawner would prefer a stale last_world_pos from the previous level.
	rec.last_cell = Vector2i(-1, -1)
	rec.last_world_pos = Vector2.ZERO
	rec.pending_level_id = Enums.Levels.NONE
	rec.pending_spawn_id = Enums.SpawnId.NONE
	_agents[agent_id] = rec
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
		rec.last_cell == Vector2i(-1, -1)
		and rec.current_level_id != Enums.Levels.NONE
		and rec.current_level_id != active_level_id
	):
		return

	rec.last_cell = cell
	rec.last_world_pos = world_pos
	rec.current_level_id = active_level_id
	_agents[rec.agent_id] = rec

func debug_get_agents() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	return _agents

func _get_active_level_id() -> Enums.Levels:
	if GameManager != null:
		return GameManager.get_active_level_id()
	return Enums.Levels.NONE