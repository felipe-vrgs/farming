class_name ToolData
extends ItemData

@export var action_kind: Enums.ToolActionKind = Enums.ToolActionKind.NONE
@export var use_duration: float = 0.2
@export var animation_prefix: StringName = &""

@export_group("Tier")
@export var tier: int = 1
@export var tool_atlas: AtlasTexture = null
@export var tool_atlas_size: Vector2 = Vector2(16, 16)

@export_group("Energy")
## Hybrid drain: cost paid on swing attempt (regardless of success).
@export var energy_cost_attempt: float = 0.0
## Additional cost paid only when the tool interaction succeeds.
@export var energy_cost_success: float = 0.0

@export_group("Damage")
@export var damage_base: int = 13
@export var damage_scaling: int = 12
@export var damage_max: int = 50

## Feedback settings
@export_group("Feedback")
@export var player_recoil: bool = false
@export var sound_charge: AudioStream
@export var sound_swing: AudioStream
@export var sound_success: AudioStream
@export var sound_fail: AudioStream
@export var has_charge: bool = false
@export var swish_type: Enums.ToolSwishType = Enums.ToolSwishType.NONE

## Generic dictionary for tool-specific data (e.g. seed plant_id)
var extra_data: Dictionary = {}


func _init() -> void:
	# Tools should not stack in inventory.
	stackable = false
	max_stack = 1


func try_use(cell: Vector2i, actor: Node = null) -> bool:
	var ctx := InteractionContext.new()
	ctx.kind = InteractionContext.Kind.TOOL
	ctx.actor = actor
	ctx.tool_data = self
	ctx.cell = cell
	return WorldGrid.try_interact(ctx)
