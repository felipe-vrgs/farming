class_name AgentComponent
extends Node

## AgentComponent - declares the parent as an "agent" (Player or NPC).
##
## Level tracking architecture:
## - NPCs: current_level_id is ONLY changed by AgentRegistry.commit_travel_by_id()
## - Player: current_level_id is set by capture_into_record() after scene-based travel
@export var kind: Enums.AgentKind = Enums.AgentKind.NONE

## Optional stable id. For Player you can set this to &"player".
@export var agent_id: StringName = &""

## Optional tool manager reference. For system to apply the record to the tool manager.
@export var tool_manager: ToolManager = null

func _enter_tree() -> void:
	# Allow discovery without relying on node paths ("AgentComponent" vs "Components/AgentComponent").
	add_to_group(Groups.AGENT_COMPONENTS)

func apply_record(rec: AgentRecord, apply_position: bool = true) -> void:
	if rec == null:
		return
	var agent := _get_agent_node()
	if agent == null:
		return

	# Position is optional (travel/spawn markers may override).
	if apply_position and agent is Node2D:
		# `AgentRecord.last_world_pos` is defined as the agent's origin (`global_position`).
		agent.global_position = rec.last_world_pos

	# Defer non-position application until the node is ready (so onready refs like ToolManager exist).
	if agent is Node and not (agent as Node).is_node_ready():
		call_deferred("_apply_record_deferred", rec)
		return

	_apply_record_to_parent(rec)

func _apply_record_deferred(rec: AgentRecord) -> void:
	var agent := _get_agent_node()
	if agent == null:
		return
	_apply_record_to_parent(rec)

func _apply_record_to_parent(rec: AgentRecord) -> void:
	var agent := _get_agent_node()
	if agent == null:
		return

	if "inventory" in agent:
		if rec.inventory != null:
			agent.inventory = rec.inventory
		if agent.inventory != null and String(agent.inventory.resource_path).begins_with("res://"):
			agent.inventory = agent.inventory.duplicate(true)
	if tool_manager != null:
		tool_manager.apply_selection(rec.selected_tool_id, rec.selected_seed_id)

	# Prefer a typed hook on the agent node.
	if agent.has_method("apply_agent_record"):
		agent.call("apply_agent_record", rec)
		return

func capture_into_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	var agent := _get_agent_node()
	if agent == null:
		return

	# If the agent has been committed to travel to a *different* level, don't let runtime capture
	# in the current scene overwrite the committed destination / spawn intent.
	var active_level_id: Enums.Levels = GameManager.get_active_level_id()
	var committed_elsewhere := (
		rec.current_level_id != Enums.Levels.NONE
		and rec.current_level_id != active_level_id
	)

	# Always capture location (so the record is valid even before the agent moves),
	# unless travel has been committed elsewhere.
	if not committed_elsewhere:
		if agent is Node2D:
			# `AgentRecord.last_world_pos` is the agent origin (`global_position`).
			rec.last_world_pos = (agent as Node2D).global_position
			if TileMapManager != null:
				rec.last_cell = TileMapManager.global_to_cell(rec.last_world_pos)

		# PLAYER: current_level_id is set here because player uses scene-based travel.
		# NPCs: current_level_id is ONLY set by AgentRegistry.commit_travel_by_id().
		if kind == Enums.AgentKind.PLAYER and active_level_id != Enums.Levels.NONE:
			rec.current_level_id = active_level_id

	if "inventory" in agent and agent.inventory != null:
		rec.inventory = agent.inventory
	if tool_manager != null:
		rec.selected_tool_id = tool_manager.get_selected_tool_id()
		rec.selected_seed_id = tool_manager.get_selected_seed_id()

	# Prefer a typed hook on the agent node.
	if agent.has_method("capture_agent_record"):
		agent.call("capture_agent_record", rec)
		return

func _get_agent_node() -> Node:
	# Components can be attached directly to the agent node,
	# or under an intermediate `Components` container.
	var p := get_parent()
	if p == null:
		return null
	if p.name == "Components" and p.get_parent() != null:
		return p.get_parent()
	return p
