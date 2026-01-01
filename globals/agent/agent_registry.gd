extends Node

## AgentRegistry - authoritative store for agent state across levels.
##
## Architecture: Pure data store + travel commit API
## ─────────────────────────────────────────────────────────────
## `current_level_id` is ONLY modified by `commit_travel_by_id()`.
## This function is called by:
##   - TravelZone (player walks into portal)
##   - AgentBrain (NPC reaches portal, online or offline)

# Prevent immediate travel re-triggering after a commit (spawn overlap bounce).
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

func load_from_session() -> void:
	if SaveManager == null:
		return
	_agents.clear()
	var a := SaveManager.load_session_agents_save()
	if a == null:
		return
	for rec in a.agents:
		if rec == null or not rec.is_valid():
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
		var kind: Enums.AgentKind = (ac as AgentComponent).kind
		if kind != Enums.AgentKind.PLAYER:
			push_warning(
				"AgentRegistry: Refusing to register non-player agent with empty agent_id: %s"
				% str(agent.get_path()))
			return null
		agent_id = StringName("player_%d" % int(agent.get_instance_id()))

	var rec: AgentRecord = get_record(agent_id) as AgentRecord
	var is_new := false
	if rec == null:
		rec = AgentRecord.new()
		rec.agent_id = agent_id
		is_new = true

	rec.kind = (ac as AgentComponent).kind
	if is_new:
		rec.current_level_id = _get_active_level_id()
	_agents[agent_id] = rec
	return rec

## TravelIntent: queue travel for an agent id.
func set_travel_intent(
	agent_id: StringName,
	target_spawn_point: SpawnPointData,
	expires_absolute_minute: int = -1
) -> bool:
	if String(agent_id).is_empty():
		return false
	if target_spawn_point == null or not target_spawn_point.is_valid():
		return false

	var rec: AgentRecord = get_record(agent_id) as AgentRecord
	if rec == null:
		rec = AgentRecord.new()
		rec.agent_id = agent_id

	rec.pending_level_id = target_spawn_point.level_id
	rec.pending_spawn_point_path = target_spawn_point.resource_path
	rec.pending_expires_absolute_minute = int(expires_absolute_minute)
	_agents[agent_id] = rec
	return true

## THE ONLY function that modifies current_level_id.
func commit_travel_by_id(agent_id: StringName, target_spawn_point: SpawnPointData) -> bool:
	if String(agent_id).is_empty():
		return false
	if target_spawn_point == null or not target_spawn_point.is_valid():
		return false

	var rec: AgentRecord = get_record(agent_id) as AgentRecord
	if rec == null:
		rec = AgentRecord.new()
		rec.agent_id = agent_id
	_agents[agent_id] = rec

	rec.current_level_id = target_spawn_point.level_id
	rec.last_spawn_point_path = target_spawn_point.resource_path
	rec.last_world_pos = target_spawn_point.position

	# NPCs that travel into an OFFLINE level should spawn at simulated position, not marker.
	var active_level_id: Enums.Levels = _get_active_level_id()
	rec.needs_spawn_marker = true
	if rec.kind == Enums.AgentKind.NPC and active_level_id != target_spawn_point.level_id:
		rec.needs_spawn_marker = false

	_travel_cooldown_until_msec[rec.agent_id] = int(Time.get_ticks_msec() + _TRAVEL_COOLDOWN_MSEC)
	# Clear pending intent
	rec.pending_level_id = Enums.Levels.NONE
	rec.pending_spawn_point_path = ""
	rec.pending_expires_absolute_minute = -1
	_agents[agent_id] = rec
	return true

## Convenience: commit travel + persist + sync spawned agents.
func commit_travel_and_sync(agent_id: StringName, target_spawn_point: SpawnPointData) -> bool:
	var ok := commit_travel_by_id(agent_id, target_spawn_point)
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

	var active_level_id: Enums.Levels = _get_active_level_id()
	if rec.current_level_id != Enums.Levels.NONE and rec.current_level_id != active_level_id:
		return

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
