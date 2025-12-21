class_name ToolData
extends Resource

enum ActionKind {
	NONE = 0,
	HOE = 1,
	WATER = 2,
	SHOVEL = 3,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var action_kind: ActionKind = ActionKind.NONE

## How long the "use tool" action should take (seconds). Useful for future action states.
@export var use_duration: float = 0.2

## Base animation prefix for this tool (e.g. "hoe", "water", "shovel").
## You can build directional animations like "{animation_prefix}_left" later.
@export var animation_prefix: StringName = &""

