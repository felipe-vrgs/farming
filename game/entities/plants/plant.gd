class_name Plant
extends Node2D

const PLANT_PASS_THROUGH_SOUND_PATH := preload("res://assets/sounds/effects/plant.ogg")

@export var data: PlantData
@export var days_grown: int = 0
@export var variant_index: int = -1
@export var wiggle_seed: int = -1

@onready var sprite: Sprite2D = $Sprite2D
@onready var state_machine: StateMachine = $StateMachine
@onready var save_component: SaveComponent = $SaveComponent
@onready var pass_through_area: Area2D = $PassThroughArea

var _base_sprite_position: Vector2 = Vector2.ZERO
var _base_sprite_rotation: float = 0.0
var _wiggle_tween: Tween = null
var _wiggle_pos_scale: float = 1.0
var _wiggle_rot_scale: float = 1.0
var _wiggle_time_scale: float = 1.0
var _wiggle_dir: float = 1.0


func _ready() -> void:
	if save_component:
		save_component.state_applied.connect(_initialize_state_from_data)

	if pass_through_area:
		pass_through_area.body_entered.connect(_on_pass_through_body_entered)

	# Connect to state machine
	state_machine.state_binding_requested.connect(_on_state_binding_requested)
	# Initial setup
	_initialize_state_from_data()

	if sprite:
		sprite.visible = true


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
	if sprite == null or data == null:
		return
	if data.source_atlas == null:
		return

	# Ensure variant is valid (can happen if variant_count changes between saves).
	var max_var := maxi(0, data.variant_count - 1)
	if variant_index < 0 or variant_index > max_var:
		variant_index = randi() % (max_var + 1)

	sprite.texture = data.source_atlas
	sprite.region_enabled = true
	sprite.region_rect = data.get_region_rect(stage_idx, variant_index)
	sprite.visible = true


func _on_state_binding_requested(state: State) -> void:
	state.bind_parent(self)


## Called by simulation (Offline/Online) to apply pre-calculated growth.
func apply_simulated_growth(new_days: int) -> void:
	if new_days == days_grown:
		return

	days_grown = new_days
	var stage_idx := get_stage_idx()
	update_visuals(stage_idx)

	if state_machine.get_state(PlantStateNames.WITHERED) == state_machine.current_state:
		return

	var desired_state := PlantStateNames.SEED
	if data == null:
		desired_state = PlantStateNames.SEED
	elif data.stage_count <= 1 or data.days_to_grow <= 0 or stage_idx >= (data.stage_count - 1):
		desired_state = PlantStateNames.MATURE
	elif stage_idx > 0:
		desired_state = PlantStateNames.GROWING

	state_machine.change_state(desired_state)


func on_interact(_tool_data: ToolData, _cell: Vector2i = Vector2i.ZERO) -> bool:
	if state_machine.current_state is PlantState:
		return (state_machine.current_state as PlantState).on_interact(_tool_data, _cell)
	return false


func _initialize_state_from_data() -> void:
	if data == null or !is_inside_tree():
		return

	# Initialize random variant once (persisted via SaveComponent).
	if variant_index < 0:
		var max_var := maxi(0, data.variant_count - 1)
		variant_index = randi() % (max_var + 1)

	# Initialize per-plant wiggle seed once (persisted via SaveComponent).
	if wiggle_seed < 0:
		wiggle_seed = randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(wiggle_seed)
	_wiggle_pos_scale = rng.randf_range(0.85, 1.25)
	_wiggle_rot_scale = rng.randf_range(0.85, 1.25)
	_wiggle_time_scale = rng.randf_range(0.9, 1.15)
	_wiggle_dir = -1.0 if rng.randf() < 0.5 else 1.0

	if sprite != null:
		sprite.centered = false
		sprite.position = data.display_offset
		_base_sprite_position = sprite.position
		_base_sprite_rotation = sprite.rotation
	var stage_idx := get_stage_idx()

	var start_state = PlantStateNames.SEED
	if data.stage_count <= 1 or data.days_to_grow <= 0 or stage_idx >= (data.stage_count - 1):
		start_state = PlantStateNames.MATURE
	elif stage_idx > 0:
		start_state = PlantStateNames.GROWING

	if sprite != null:
		sprite.visible = true
	# Re-init state machine if needed, or just force visual update
	if state_machine.current_state == null:
		state_machine.init(start_state)
	else:
		# If we are reloading state, we might need to transition
		state_machine.change_state(start_state)

	update_visuals(stage_idx)


func _on_pass_through_body_entered(_body: Node2D) -> void:
	# Only once we are past the seed stage.
	if get_stage_idx() <= 0:
		return

	# Shake
	if sprite and data:
		# Kill any in-flight wiggle and snap to base pose.
		if _wiggle_tween != null and is_instance_valid(_wiggle_tween):
			_wiggle_tween.kill()
		sprite.position = _base_sprite_position
		sprite.rotation = _base_sprite_rotation

		# Much stronger + readable wiggle (still returns to base pose).
		var amp_pos := Vector2(0.6, 0.3) * _wiggle_pos_scale
		amp_pos.x *= _wiggle_dir
		var amp_rot := 0.06 * _wiggle_rot_scale * _wiggle_dir

		var t1 := 0.06 * _wiggle_time_scale
		var t2 := 0.06 * _wiggle_time_scale
		var t3 := 0.06 * _wiggle_time_scale
		var t4 := 0.12 * _wiggle_time_scale

		_wiggle_tween = create_tween()
		_wiggle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# Immediate kick so it always reads (even if tween is very fast).
		sprite.position = _base_sprite_position + amp_pos
		sprite.rotation = _base_sprite_rotation + amp_rot

		# Step 1
		_wiggle_tween.set_parallel(true)
		_wiggle_tween.tween_property(sprite, "position", _base_sprite_position - amp_pos, t1)
		_wiggle_tween.tween_property(sprite, "rotation", _base_sprite_rotation - amp_rot, t1)
		_wiggle_tween.set_parallel(false)

		# Step 2
		_wiggle_tween.set_parallel(true)
		_wiggle_tween.tween_property(
			sprite, "position", _base_sprite_position + (amp_pos * 0.7), t2
		)
		_wiggle_tween.tween_property(
			sprite, "rotation", _base_sprite_rotation + (amp_rot * 0.7), t2
		)
		_wiggle_tween.set_parallel(false)

		# Step 3
		_wiggle_tween.set_parallel(true)
		_wiggle_tween.tween_property(
			sprite, "position", _base_sprite_position - (amp_pos * 0.4), t3
		)
		_wiggle_tween.tween_property(
			sprite, "rotation", _base_sprite_rotation - (amp_rot * 0.4), t3
		)
		_wiggle_tween.set_parallel(false)

		# Return
		_wiggle_tween.set_parallel(true)
		_wiggle_tween.tween_property(sprite, "position", _base_sprite_position, t4)
		_wiggle_tween.tween_property(sprite, "rotation", _base_sprite_rotation, t4)
		_wiggle_tween.set_parallel(false)

	# SFX
	if SFXManager:
		SFXManager.play_effect(
			PLANT_PASS_THROUGH_SOUND_PATH, global_position, Vector2(0.95, 1.05), -12.0
		)
