class_name ToolData
extends ItemData

@export var action_kind: Enums.ToolActionKind = Enums.ToolActionKind.NONE
@export var use_duration: float = 0.2
## Legacy: older player sprites baked the tool into the body animation (e.g. `axe_front`).
## Kept for back-compat while migrating to decoupled tool sprites.
@export var animation_prefix: StringName = &""
## Data-driven player body animation base to request during tool use.
## This should match the animation names in the Player SpriteFrames (direction suffix is appended).
@export var player_body_anim: StringName = &"swing"

@export_group("Tier")
@export var tier: int = 1
@export var tool_atlas: AtlasTexture = null
@export var tool_atlas_size: Vector2 = Vector2(16, 16)
## SpriteFrames used by HandTool to render the equipped tool (e.g. `iron_front/back/left/right`).
@export var tool_sprite_frames: SpriteFrames = null
## Current art pipeline naming convention: `<tier>_<direction>` (hardcode `iron` for now).
@export var tool_sprite_tier: StringName = &"iron"

@export_group("ToolSpriteOffsets")
## Applied on top of `HandTool` ToolMarkers positions.
## Use this when a specific tool (e.g. watering can) needs different alignment.
@export var tool_offset_front: Vector2 = Vector2.ZERO
@export var tool_offset_back: Vector2 = Vector2.ZERO
@export var tool_offset_left: Vector2 = Vector2.ZERO
@export var tool_offset_right: Vector2 = Vector2.ZERO

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
