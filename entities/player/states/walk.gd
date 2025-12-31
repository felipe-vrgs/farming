extends PlayerState

func enter() -> void:
	super.enter()
	player.footsteps_component.clear_timer()

func process_input(event: InputEvent) -> StringName:
	if player and player.player_input_config:
		if event.is_action_pressed(player.player_input_config.action_interact):
			if player.tool_manager.can_use_tool():
				return PlayerStateNames.TOOL_CHARGING
	return PlayerStateNames.NONE

func process_physics(delta: float) -> StringName:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		return PlayerStateNames.IDLE

	if player and player_balance_config:
		var target_velocity = input_dir * player_balance_config.move_speed
		var acceleration = player_balance_config.acceleration * delta
		player.velocity = player.velocity.move_toward(target_velocity, acceleration)

		update_animation(input_dir)
		player.footsteps_component.play_footstep(delta)

	return PlayerStateNames.NONE

func update_animation(_input_dir: Vector2) -> void:
	if player == null or player.animated_sprite == null:
		return

	animation_change_requested.emit(&"move")
