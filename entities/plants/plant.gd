class_name Plant
extends Node2D

@export var data: PlantData
@export var days_grown: int = 0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine
@onready var save_component: SaveComponent = $SaveComponent

func _ready() -> void:
	if save_component:
		save_component.state_applied.connect(_initialize_state_from_data)

	# Connect to state machine
	state_machine.state_binding_requested.connect(_on_state_binding_requested)
	# Initial setup
	_initialize_state_from_data()

	if animated_sprite:
		animated_sprite.visible = true

func get_stage_idx() -> int:
	if data == null:
		return 0

	var max_stage: int = max(0, data.stage_count - 1)
	if max_stage == 0:
		return 0

	# Instant growth (or invalid config) -> last stage.
	if data.days_to_grow <= 0:
		return max_stage

	# days_grown is "watered days so far"; map it to a stage index [0..max_stage].
	var t := float(days_grown) / float(data.days_to_grow)
	# Use stage_count to ensure we can reach all stages including the last one.
	return clampi(floori(t * float(data.stage_count - 0.01)), 0, max_stage)

func update_visuals(stage_idx: int) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	animated_sprite.visible = true
	var anim_name := "stage_%d" % stage_idx
	if animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)

func _on_state_binding_requested(state: State) -> void:
	state.bind_parent(self)

func on_day_passed(is_wet: bool) -> void:
	if state_machine.current_state is PlantState:
		var new_state = (state_machine.current_state as PlantState).on_day_passed(is_wet)
		if new_state != PlantStateNames.NONE:
			state_machine.change_state(new_state)

func on_interact(_tool_data: ToolData, _cell: Vector2i = Vector2i.ZERO) -> bool:
	if state_machine.current_state is PlantState:
		return (state_machine.current_state as PlantState).on_interact(_tool_data, _cell)
	return false

func _initialize_state_from_data() -> void:
	if data == null or !is_inside_tree():
		return

	animated_sprite.sprite_frames = data.growth_animations
	var stage_idx := get_stage_idx()

	var start_state = PlantStateNames.SEED
	if data.stage_count <= 1 or data.days_to_grow <= 0 or stage_idx >= (data.stage_count - 1):
		start_state = PlantStateNames.MATURE
	elif stage_idx > 0:
		start_state = PlantStateNames.GROWING

	animated_sprite.visible = true
	# Re-init state machine if needed, or just force visual update
	if state_machine.current_state == null:
		state_machine.init(start_state)
	else:
		# If we are reloading state, we might need to transition
		state_machine.change_state(start_state)

	update_visuals(stage_idx)
