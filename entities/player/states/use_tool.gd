extends State

var _elapsed: float = 0.0

func enter() -> void:
	_elapsed = 0.0
	if parent == null:
		return

	# Stop movement for the tool action.
	parent.velocity = Vector2.ZERO

	# Player will append the facing suffix (left/right/front/back).
	# Here we emit only the tool base prefix (e.g. "hoe", "water", "axe").
	var anim_base := _compute_tool_animation_base()
	if not String(anim_base).is_empty():
		animation_change_requested.emit(anim_base)

	# Apply gameplay effect immediately for now (later you can time this to an animation frame).
	parent.interactivity_manager.interact(parent)

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
