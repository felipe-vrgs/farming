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

func update_animation(_input_dir: Vector2) -> void:
	if parent == null or parent.animated_sprite == null:
		return

	# Player will append the facing suffix (left/right/front/back).
	# We keep direction tracking in `InteractivityManager`, so states only choose the base.
	animation_change_requested.emit(&"move")
