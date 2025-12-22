class_name Plant
extends GridEntity

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _init() -> void:
	entity_type = EntityType.PLANT
	blocks_movement = false

func _ready() -> void:
	# Base class calls _snap_to_grid and _register_on_grid
	super._ready()

	# Initial visual update
	refresh()

func refresh() -> void:
	if animated_sprite == null:
		return

	var data := GridState.get_or_create_cell_data(grid_pos)
	if data == null or String(data.plant_id).is_empty():
		animated_sprite.visible = false
		return

	animated_sprite.visible = true

	var plant_res: PlantData = GridState.get_plant_data(data.plant_id)
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
