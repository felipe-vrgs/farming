extends State

func enter() -> void:
	super.enter()
	animation_change_requested.emit(PlayerStateNames.IDLE)

func process_input(event: InputEvent) -> StringName:
	if parent and parent.player_input_config:
		if event.is_action_pressed(parent.player_input_config.action_interact):
			return PlayerStateNames.TOOL_CHARGING
	return PlayerStateNames.NONE

func process_physics(delta: float) -> StringName:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		return PlayerStateNames.WALK

	# Apply friction
	if parent and player_balance_config:
		var friction = player_balance_config.friction * delta
		parent.velocity = parent.velocity.move_toward(Vector2.ZERO, friction)

	return PlayerStateNames.NONE
