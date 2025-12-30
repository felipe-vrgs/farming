class_name AgentComponent
extends Node

## Declares the parent as an "agent" (Player or NPC) and provides a stable identity hook.
## Next step: a global AgentRegistry can listen to movement + level travel and track agents cross-level.

@export var kind: Enums.AgentKind = Enums.AgentKind.NONE

## Optional stable id. For Player you can set this to &"player".
@export var agent_id: StringName = &""

func _ready() -> void:
	var p := get_parent()
	if p:
		p.add_to_group(&"agents")
		if kind == Enums.AgentKind.PLAYER:
			p.add_to_group(&"player_agent")


