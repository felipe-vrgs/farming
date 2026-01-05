@tool
class_name PlantData
extends Resource

## The name of the plant displayed to the player
@export var plant_name: String = "Unnamed Plant"

## How many days it takes to reach maturity
@export var days_to_grow: int = 3

## The item name produced when harvested
@export var harvest_item: ItemData

@export var loot_amount: int = 1
@export var spawn_count: int = 1

## Holds animations for each stage, named "stage_0", "stage_1", etc.
@export var growth_animations: SpriteFrames

@export_group("Atlas Helper")
## Click this checkbox in the inspector to force a refresh!
@export var trigger_refresh: bool = false:
	set(v):
		_generate_from_atlas()

## Drag your plant atlas here.
@export var source_atlas: Texture2D:
	set(v):
		source_atlas = v
		_generate_from_atlas()

## Size of a single sprite (e.g., 18x32 for your turnips).
@export var region_size: Vector2i = Vector2i(18, 32):
	set(v):
		region_size = v
		_generate_from_atlas()

## Pixel position of the first sprout.
@export var start_offset: Vector2i = Vector2i(0, 0):
	set(v):
		start_offset = v
		_generate_from_atlas()

## How many growth stages are in this row?
@export var stage_count: int = 1:
	set(v):
		stage_count = max(1, v)
		_generate_from_atlas()

## Frames per animation (if you want the helper to generate multi-frame anims)
## For now, defaults to 1 (static image per stage).
@export var frames_per_stage: int = 1:
	set(v):
		frames_per_stage = max(1, v)
		_generate_from_atlas()

@export var ping_pong: bool = false:
	set(v):
		ping_pong = v
		_generate_from_atlas()

@export var animation_speed: float = 5.0:
	set(v):
		animation_speed = v
		_generate_from_atlas()


func _generate_from_atlas() -> void:
	if not Engine.is_editor_hint():
		return

	if source_atlas == null:
		print_rich("[color=yellow]PlantData: Cannot generate, source_atlas is empty.[/color]")
		return

	var msg = "[color=cyan]PlantData: Generating %d stages from '%s'...[/color]"
	print_rich(msg % [stage_count, plant_name])

	# Create new SpriteFrames if missing, otherwise clear existing
	if growth_animations == null:
		growth_animations = SpriteFrames.new()
	else:
		growth_animations.clear_all()

	for stage_idx in range(stage_count):
		var anim_name = "stage_%d" % stage_idx
		growth_animations.add_animation(anim_name)
		growth_animations.set_animation_loop(anim_name, true)
		growth_animations.set_animation_speed(anim_name, animation_speed)

		var stage_textures: Array[AtlasTexture] = []

		for frame_idx in range(frames_per_stage):
			var tex := AtlasTexture.new()
			tex.atlas = source_atlas

			# Grid Layout Logic:
			# X axis = Animation Frames
			# Y axis = Growth Stages
			tex.region = Rect2(
				start_offset.x + (frame_idx * region_size.x),
				start_offset.y + (stage_idx * region_size.y),
				region_size.x,
				region_size.y
			)
			growth_animations.add_frame(anim_name, tex)
			stage_textures.append(tex)

		# Add reverse frames for ping-pong effect if enabled
		if ping_pong and frames_per_stage > 2:
			# For 3 frames (0,1,2), we add frame 1 at the end to get 0,1,2,1
			for i in range(frames_per_stage - 2, 0, -1):
				growth_animations.add_frame(anim_name, stage_textures[i])

	# Automatically update days_to_grow to match the number of stages.
	days_to_grow = max(0, stage_count - 1)

	emit_changed()
	notify_property_list_changed()
