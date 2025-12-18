extends State

func enter() -> void:
	super.enter()
	# Animation handling is done in super.enter() via animation_name export

func process_physics(delta: float) -> StringName:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		return PlayerStateNames.WALK

	# Apply friction
	if parent and player_balance_config:
		var friction = player_balance_config.friction * delta
		parent.velocity = parent.velocity.move_toward(Vector2.ZERO, friction)

	return PlayerStateNames.NONE
