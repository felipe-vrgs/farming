class_name Soil
extends Area2D

signal plant_grown
signal plant_harvested

## Terrain Set ID in your TileSet (Check your TileSet resource)
const TERRAIN_SET_ID = 0
## Terrain ID for Dry Soil
const TERRAIN_DRY = 5
## Terrain ID for Wet Soil
const TERRAIN_WET = 6

@export var plant_data_res: PlantData

## The currently planted crop data. Null if nothing planted.
var planted_crop: PlantData
## Current growth progress (days).
var days_grown: int = 0
## Current visual stage index.
var current_growth_stage: int = 0

var is_wet: bool = false:
	set(value):
		is_wet = value
		_update_ground_visuals()

## Coordinates of this plot on the TileMap grid
var tile_coords: Vector2i
## Reference to the TileMap (or TileMapLayer) managing the ground
var _tile_map_layer: TileMapLayer


@onready var plant_sprite: Sprite2D = $PlantSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func setup(coords: Vector2i, tile_map_layer: TileMapLayer) -> void:
	self.tile_coords = coords
	self._tile_map_layer = tile_map_layer
	# Snap position to grid center
	self.position = tile_map_layer.map_to_local(coords)
	_update_ground_visuals()

func _ready() -> void:
	_update_plant_visual()

## Water the soil. Usually called by the player with a watering can.
func water() -> void:
	self.is_wet = true

## Plant a seed.
func plant_seed(seed_data: PlantData) -> void:
	if planted_crop:
		print("Soil already has a plant.")
		return

	planted_crop = seed_data
	days_grown = 0
	current_growth_stage = 0
	_update_plant_visual()
	print("Planted " + seed_data.plant_name)

## Advance the day. Handles growth logic.
func on_new_day() -> void:
	if is_wet and planted_crop:
		days_grown += 1
		_check_growth()

	# Dry out for the new day
	self.is_wet = false

## Harvest the plant if ready. Returns the item name or null.
func harvest() -> String:
	if not planted_crop:
		return ""

	if _is_fully_grown():
		var item = planted_crop.harvest_item_name
		planted_crop = null
		days_grown = 0
		current_growth_stage = 0
		_update_plant_visual()
		plant_harvested.emit()
		return item

	return ""

func _update_ground_visuals() -> void:
	if not _tile_map_layer:
		return

	# Update the terrain on the TileMap
	var target_terrain = TERRAIN_WET if is_wet else TERRAIN_DRY

	# Note: This connects terrains (autotiling)
	_tile_map_layer.set_cells_terrain_connect([tile_coords], TERRAIN_SET_ID, target_terrain)

func _is_fully_grown() -> bool:
	if not planted_crop:
		return false
	return current_growth_stage >= planted_crop.sprites.size() - 1

func _check_growth() -> void:
	if not planted_crop:
		return

	var total_stages = planted_crop.sprites.size()
	if total_stages == 0:
		return

	var growth_progress = float(days_grown) / float(planted_crop.days_to_grow)
	if growth_progress > 1.0:
		growth_progress = 1.0

	var target_stage = int(growth_progress * (total_stages - 1))

	if target_stage != current_growth_stage:
		current_growth_stage = target_stage
		_update_plant_visual()

		if _is_fully_grown():
			plant_grown.emit()

func _update_plant_visual() -> void:
	if not plant_sprite:
		return

	if not planted_crop:
		plant_sprite.texture = null
		return

	if planted_crop.sprites.size() > current_growth_stage:
		plant_sprite.texture = planted_crop.sprites[current_growth_stage]
