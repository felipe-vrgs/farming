class_name AgentComponent
extends Node

## Declares the parent as an "agent" (Player or NPC) and provides a stable identity hook.
@export var kind: Enums.AgentKind = Enums.AgentKind.NONE

## Optional stable id. For Player you can set this to &"player".
@export var agent_id: StringName = &""

func _enter_tree() -> void:
	# Allow discovery without relying on node paths ("AgentComponent" vs "Components/AgentComponent").
	add_to_group(Groups.AGENT_COMPONENTS)
