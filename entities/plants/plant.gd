class_name Plant
extends Node2D


## Coordinates of this plant on the TileMap grid
var tile_coords: Vector2i

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func setup(coords: Vector2i) -> void:
	tile_coords = coords
	visible = true
	z_index = 5
	refresh()

func refresh() -> void:
	if animated_sprite == null:
		return

	var data := SoilGridState.get_or_create_cell_data(tile_coords)
	if data == null or String(data.plant_id).is_empty():
		animated_sprite.visible = false
		return

	animated_sprite.visible = true

	var plant_res: PlantData = SoilGridState.get_plant_data(data.plant_id)
	if plant_res == null or plant_res.growth_animations == null:
		return

	animated_sprite.sprite_frames = plant_res.growth_animations

	# Use the stage_count from data to clamp safely
	var max_stage_idx := plant_res.stage_count - 1
	var stage_idx := clampi(data.growth_stage, 0, max_stage_idx)
	var anim_name := "stage_%d" % stage_idx

	if animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
		# print("Plant: Playing animation %s for %s" % [anim_name, plant_res.plant_name])


