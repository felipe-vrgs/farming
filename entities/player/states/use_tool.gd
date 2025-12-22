extends State

const PARTICLES_SCENE: PackedScene = preload("res://entities/particles/one_shot_particles.tscn")

var _elapsed: float = 0.0
var _did_apply: bool = false
var _target_cell: Variant = null

func enter() -> void:
	_elapsed = 0.0
	_did_apply = false
	if parent == null:
		return

	# Stop movement for the tool action.
	parent.velocity = Vector2.ZERO

	# Player will append the facing suffix (left/right/front/back).
	# Here we emit only the tool base prefix (e.g. "hoe", "water", "axe").
	var anim_base := _compute_tool_animation_base()
	if not String(anim_base).is_empty():
		animation_change_requested.emit(anim_base)

	# Cache the target cell at the start of the animation.
	# We'll apply the tool half-way through use_duration.
	_target_cell = parent.interactivity_manager.get_front_cell(parent)

func process_input(event: InputEvent) -> StringName:
	# Ignore re-trigger while already using a tool.
	if parent == null || parent.player_input_config == null:
		return PlayerStateNames.NONE
	if event.is_action_pressed(parent.player_input_config.action_interact):
		return PlayerStateNames.NONE
	return PlayerStateNames.NONE

func process_physics(_delta: float) -> StringName:
	# Keep player still during use.
	if parent != null:
		parent.velocity = Vector2.ZERO
	return PlayerStateNames.NONE

func process_frame(delta: float) -> StringName:
	if parent == null or parent.equipped_tool == null:
		return PlayerStateNames.IDLE

	_elapsed += delta

	# Apply tool at half-way point, if we have a valid target cell.
	if not _did_apply and _target_cell != null:
		var half := parent.equipped_tool.use_duration * 0.5
		if _elapsed >= half:
			_did_apply = true
			var ok := parent.equipped_tool.try_use(parent, _target_cell as Vector2i)
			if ok:
				_spawn_particles_at_target(_target_cell as Vector2i)

	if _elapsed < parent.equipped_tool.use_duration:
		return PlayerStateNames.NONE

	# After tool use, return to movement states depending on input.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		return PlayerStateNames.IDLE
	return PlayerStateNames.WALK

func _compute_tool_animation_base() -> StringName:
	if parent == null or parent.equipped_tool == null:
		return &""

	var prefix := parent.equipped_tool.animation_prefix
	if String(prefix).is_empty():
		return &""
	return prefix

func _spawn_particles_at_target(cell: Vector2i) -> void:
	if parent == null or parent.interactivity_manager == null:
		return

	var p := PARTICLES_SCENE.instantiate()
	if not (p is Node2D):
		return

	# Add to player scene (requested), but particles are top_level so they won't move with player.
	parent.add_child(p)
	(p as Node2D).global_position = parent.interactivity_manager.cell_to_global_center(cell)
