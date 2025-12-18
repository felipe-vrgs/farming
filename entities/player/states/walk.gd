extends State

func enter() -> void:
	super.enter()

func process_physics(delta: float) -> StringName:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir == Vector2.ZERO:
		return PlayerStateNames.IDLE

	if parent and player_balance_config:
		var target_velocity = input_dir * player_balance_config.move_speed
		var acceleration = player_balance_config.acceleration * delta
		parent.velocity = parent.velocity.move_toward(target_velocity, acceleration)

		update_sprite_direction(input_dir.x)

	return PlayerStateNames.NONE
