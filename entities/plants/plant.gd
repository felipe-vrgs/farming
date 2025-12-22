class_name Plant
extends Node2D


## Coordinates of this plant on the TileMap grid
var tile_coords: Vector2i

@onready var sprite: Sprite2D = $Sprite2D

func setup(coords: Vector2i) -> void:
	tile_coords = coords
	visible = true
	z_index = 5
	refresh()

func refresh() -> void:
	if sprite == null:
		return

	var data := SoilGridState.get_or_create_cell_data(tile_coords)
	if data == null or String(data.plant_id).is_empty():
		sprite.texture = null
		return

	var plant_res: PlantData = SoilGridState.get_plant_data(data.plant_id)
	if plant_res == null or plant_res.sprites.is_empty():
		sprite.texture = null
		return

	var stage := clampi(data.growth_stage, 0, plant_res.sprites.size() - 1)
	sprite.texture = plant_res.sprites[stage]
	print("Plant: Visuals updated for %s at %s" % [plant_res.plant_name, tile_coords])


