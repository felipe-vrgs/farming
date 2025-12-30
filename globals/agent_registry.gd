extends Node

## Global registry tracking agents across levels (player + NPCs).
## - NPCs can "travel" (schedule-driven) without forcing an active scene change.
## - Player travel is handled by GameManager; registry is updated for bookkeeping.

## StringName agent_id -> AgentRecord
var _agents: Dictionary = {}

func _ready() -> void:
	set_process(false)
	if EventBus != null:
		EventBus.occupant_moved_to_cell.connect(_on_occupant_moved_to_cell)

func get_record(agent_id: StringName):
	return _agents.get(agent_id)

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
	if rec == null:
		rec = AgentRecord.new()
		rec.agent_id = agent_id

	rec.kind = (ac as AgentComponent).kind
	if GameManager != null:
		rec.current_level_id = GameManager.get_active_level_id()
	else:
		rec.current_level_id = Enums.Levels.NONE
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
	rec.pending_level_id = Enums.Levels.NONE
	rec.pending_spawn_id = Enums.SpawnId.NONE
	_agents[agent_id] = rec
	return true

func _on_occupant_moved_to_cell(entity: Node, cell: Vector2i, world_pos: Vector2) -> void:
	var rec: AgentRecord = ensure_agent_registered_from_node(entity) as AgentRecord
	if rec == null:
		return
	rec.last_cell = cell
	rec.last_world_pos = world_pos
	# Keep current level id in sync with the active scene when we see movement.
	if GameManager != null:
		rec.current_level_id = GameManager.get_active_level_id()
	_agents[rec.agent_id] = rec

func debug_get_agents() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	return _agents
