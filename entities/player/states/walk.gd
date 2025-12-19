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

		update_animation(input_dir)

	return PlayerStateNames.NONE

func update_animation(input_dir: Vector2) -> void:
	if parent == null or parent.animated_sprite == null:
		return

	# Prioritize the axis with the larger magnitude, or default to horizontal if equal
	if abs(input_dir.x) >= abs(input_dir.y):
		if input_dir.x > 0:
			animation_name = "move_left"
		else:
			animation_name = "move_right"
	else:
		if input_dir.y > 0:
			animation_name = "move_front"
		else:
			animation_name = "move_back"

	animation_change_requested.emit(animation_name)
