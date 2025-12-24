class_name ToolData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var action_kind: Enums.ToolActionKind = Enums.ToolActionKind.NONE
@export var behavior: ToolBehavior

## How long the "use tool" action should take (seconds). Useful for future action states.
@export var use_duration: float = 0.2

## Base animation prefix for this tool (e.g. "hoe", "water", "shovel").
## You can build directional animations like "{animation_prefix}_left" later.
@export var animation_prefix: StringName = &""

## If set, this tool only interacts with entities of this type.
@export var target_type: Enums.EntityType = Enums.EntityType.GENERIC

## Feedback settings
@export_group("Feedback")
@export var player_recoil: bool = false
@export var sound_charge: AudioStream
@export var sound_swing: AudioStream
@export var sound_success: AudioStream
@export var sound_fail: AudioStream
@export var has_charge: bool = false
@export var swish_type: Enums.ToolSwishType = Enums.ToolSwishType.NONE

func try_use(player: Player, cell: Vector2i) -> bool:
	if behavior == null:
		return false
	return behavior.try_use(player, cell, self)
