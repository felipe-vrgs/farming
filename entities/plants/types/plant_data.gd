@tool
class_name PlantData
extends Resource

## The name of the plant displayed to the player
@export var plant_name: String = "Unnamed Plant"

## How many days it takes to reach maturity
@export var days_to_grow: int = 3

## The item name produced when harvested
@export var harvest_item_name: String

## Sprites for each growth stage.
@export var sprites: Array[Texture2D]

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

func _generate_from_atlas() -> void:
	if not Engine.is_editor_hint():
		return

	if source_atlas == null:
		print_rich("[color=yellow]PlantData: Cannot generate, source_atlas is empty.[/color]")
		return

	var msg = "[color=cyan]PlantData: Generating %d sprites for '%s'...[/color]"
	print_rich(msg % [stage_count, plant_name])

	sprites.clear()
	for i in range(stage_count):
		var tex := AtlasTexture.new()
		tex.atlas = source_atlas
		tex.region = Rect2(
			start_offset.x + (i * region_size.x),
			start_offset.y,
			region_size.x,
			region_size.y
		)
		sprites.append(tex)

	# Automatically update days_to_grow to match the number of stages.
	# (e.g., 3 stages means Day 0, 1, and 2 is mature, so 2 days to grow).
	days_to_grow = max(0, sprites.size() - 1)

	emit_changed()
	notify_property_list_changed()
