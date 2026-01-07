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

@export_group("Visuals")
## Atlas layout:
## - X axis = Variants
## - Y axis = Growth stages
@export var source_atlas: Texture2D

## Size of a single plant sprite in the atlas (e.g. 18x32).
@export var region_size: Vector2i = Vector2i(18, 32)

## Pixel position of the first sprite (stage 0, variant 0).
@export var start_offset: Vector2i = Vector2i(0, 0)

## How many growth stages exist (Y axis).
@export var stage_count: int = 1:
	set(v):
		stage_count = maxi(1, v)

## How many variants exist (X axis).
@export var variant_count: int = 1:
	set(v):
		variant_count = maxi(1, v)

## Local offset applied to the plant sprite (and placement preview) relative to the
## cell center in world space. This keeps the plant "standing on the ground".
@export var display_offset: Vector2 = Vector2(-9, -26)


func get_region_rect(stage_idx: int, variant_idx: int) -> Rect2:
	# Clamp inputs to valid ranges.
	var s := clampi(stage_idx, 0, maxi(0, stage_count - 1))
	var v := clampi(variant_idx, 0, maxi(0, variant_count - 1))
	return Rect2(
		start_offset.x + (v * region_size.x),
		start_offset.y + (s * region_size.y),
		region_size.x,
		region_size.y
	)
