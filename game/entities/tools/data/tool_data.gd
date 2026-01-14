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

@export_group("Animation")
## SpriteFrames used by HandTool to render the equipped tool (e.g. `iron_front/back/left/right`).
@export var tool_sprite_frames: SpriteFrames = null
@export var tier: StringName = &"iron"

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

## Feedback settings
@export_group("Feedback")
@export var player_recoil: bool = false
@export var sound_charge: AudioStream
@export var sound_swing: AudioStream
@export var sound_success: AudioStream
@export var sound_fail: AudioStream
@export var has_charge: bool = false
@export var swish_type: Enums.ToolSwishType = Enums.ToolSwishType.NONE

@export_group("VFX")
@export var tier_color: Color = Color(0, 0, 0, 0)

## Generic dictionary for tool-specific data (e.g. seed plant_id)
var extra_data: Dictionary = {}


func _init() -> void:
	# Tools should not stack in inventory.
	stackable = false
	max_stack = 1


func get_effect_color() -> Color:
	# Prefer explicit per-tool configuration.
	if tier_color.a > 0.0:
		return tier_color

	# Fallback: reasonable defaults based on tier name.
	var t := tier
	if String(t).is_empty():
		t = &"iron"
	match t:
		&"iron":
			return Color(0.75, 0.78, 0.82, 1.0)
		&"gold":
			return Color(1.0, 0.85, 0.25, 1.0)
		&"platinum":
			return Color(0.75, 0.92, 1.0, 1.0)
		&"ruby":
			return Color(1.0, 0.25, 0.45, 1.0)
	return Color.WHITE


func try_use(cell: Vector2i, actor: Node = null, hit_world_pos: Vector2 = Vector2.ZERO) -> bool:
	var ctx := InteractionContext.new()
	ctx.kind = InteractionContext.Kind.TOOL
	ctx.actor = actor
	ctx.tool_data = self
	ctx.cell = cell
	ctx.hit_world_pos = hit_world_pos
	var wg := _get_world_grid()
	if wg != null and is_instance_valid(wg) and wg.has_method("try_interact"):
		return bool(wg.call("try_interact", ctx))
	return false


static func _get_world_grid() -> Node:
	# Avoid a hard compile-time dependency on the `WorldGrid` autoload name so this
	# script can be compiled in tool/headless contexts (asset generators, CI scripts).
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var root := (ml as SceneTree).root
		if root != null:
			return root.get_node_or_null(NodePath("WorldGrid"))
	return null
