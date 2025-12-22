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
@export var behavior: ToolBehavior

## What VFX to play when this tool successfully hits a tile.
@export var hit_vfx: ToolHitVfxConfig

## How long the "use tool" action should take (seconds). Useful for future action states.
@export var use_duration: float = 0.2

## Base animation prefix for this tool (e.g. "hoe", "water", "shovel").
## You can build directional animations like "{animation_prefix}_left" later.
@export var animation_prefix: StringName = &""

## If set, this tool only interacts with entities of this type.
@export var target_type: GridEntity.EntityType = GridEntity.EntityType.GENERIC

func try_use(player: Player, cell: Vector2i) -> bool:
	if behavior == null:
		return false
	return behavior.try_use(player, cell, self)

