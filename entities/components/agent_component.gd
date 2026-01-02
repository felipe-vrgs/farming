class_name AgentComponent
extends Node

## AgentComponent - declares the parent as an "agent" (Player or NPC).
##
## Level tracking: ALL agents (Player + NPCs) use commit_travel_by_id() for level changes.
## This component only captures position/inventory, NOT current_level_id.
@export var kind: Enums.AgentKind = Enums.AgentKind.NONE

## Optional stable id. For Player you can set this to &"player".
@export var agent_id: StringName = &""

## Optional tool manager reference. For system to apply the record to the tool manager.
@export var tool_manager: ToolManager = null

var active_level_id: Enums.Levels = Enums.Levels.NONE

func _enter_tree() -> void:
	# Allow discovery without relying on node paths ("AgentComponent" vs "Components/AgentComponent").
	add_to_group(Groups.AGENT_COMPONENTS)

func _ready() -> void:
	if EventBus != null and not EventBus.active_level_changed.is_connected(_on_active_level_changed):
		EventBus.active_level_changed.connect(_on_active_level_changed)

func _on_active_level_changed(_prev: Enums.Levels, next: Enums.Levels) -> void:
	active_level_id = next

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

	if "facing_dir" in agent:
		agent.facing_dir = rec.facing_dir

	if "money" in agent:
		agent.money = rec.money

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

	var committed_elsewhere := (
		rec.current_level_id != Enums.Levels.NONE
		and rec.current_level_id != active_level_id
	)

	# Capture position (unless travel committed elsewhere).
	# NOTE: current_level_id is NOT set here - it's only changed by commit_travel_by_id().
	if not committed_elsewhere and agent is Node2D:
		rec.last_world_pos = (agent as Node2D).global_position
		if WorldGrid.tile_map != null:
			rec.last_cell = WorldGrid.tile_map.global_to_cell(rec.last_world_pos)

	# Capture inventory/tool state.
	if "inventory" in agent and agent.inventory != null:
		rec.inventory = agent.inventory

	if "facing_dir" in agent:
		rec.facing_dir = agent.facing_dir

	if "money" in agent:
		rec.money = agent.money

	if tool_manager != null:
		rec.selected_tool_id = tool_manager.get_selected_tool_id()
		rec.selected_seed_id = tool_manager.get_selected_seed_id()

	# Prefer a typed hook on the agent node.
	if agent.has_method("capture_agent_record"):
		agent.call("capture_agent_record", rec)

func _get_agent_node() -> Node:
	# Components can be attached directly to the agent node,
	# or under an intermediate `Components` container.
	var p := get_parent()
	if p == null:
		return null
	if p.name == "Components" and p.get_parent() != null:
		return p.get_parent()
	return p
