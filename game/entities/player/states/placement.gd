extends PlayerState

## PLACEMENT state
## - Player can move while holding an item
## - Interact attempts to place the carried item (if placeable)
## - Use still triggers normal USE interactions


func enter() -> void:
	super.enter()


func process_input(event: InputEvent) -> StringName:
	if player == null or player.player_input_config == null:
		return PlayerStateNames.NONE

	# Exit placement if we're no longer carrying an item.
	if player.tool_manager == null or not bool(player.tool_manager.call("is_in_item_mode")):
		return PlayerStateNames.IDLE

	if event.is_action_pressed(player.player_input_config.action_use):
		return PlayerStateNames.USE

	if event.is_action_pressed(player.player_input_config.action_interact):
		if player.tool_manager.can_use_tool():
			# Keep Stardew-like hard blockers (NPC / harvest) active even while carrying.
			if player.raycell_component != null and WorldGrid != null:
				var v: Variant = player.raycell_component.get_front_cell()
				if v is Vector2i and WorldGrid.try_resolve_tool_press(player, v as Vector2i):
					player.tool_manager.start_tool_cooldown()
					return PlayerStateNames.NONE

			if (
				player.placement_manager != null
				and player.placement_manager.has_method("try_place")
			):
				player.placement_manager.call("try_place")
			# Always apply a cooldown on interact attempts to avoid spam (success or fail).
			player.tool_manager.start_tool_cooldown()

			# If we placed and the stack is now empty, selection refresh will kick us out next frame.
			# Stay in placement otherwise.
			return PlayerStateNames.NONE

	return PlayerStateNames.NONE


func process_physics(delta: float) -> StringName:
	if player == null or player_balance_config == null:
		return PlayerStateNames.NONE

	# Exit placement if we're no longer carrying an item.
	if player.tool_manager == null or not bool(player.tool_manager.call("is_in_item_mode")):
		return PlayerStateNames.IDLE

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir == Vector2.ZERO:
		# Apply friction
		var friction = player_balance_config.friction * delta
		player.velocity = player.velocity.move_toward(Vector2.ZERO, friction)
		_update_animation(false)
		return PlayerStateNames.NONE

	var target_velocity = input_dir * player_balance_config.move_speed
	var acceleration = player_balance_config.acceleration * delta
	player.velocity = player.velocity.move_toward(target_velocity, acceleration)
	_update_animation(true)
	if player.footsteps_component:
		player.footsteps_component.play_footstep(delta)

	return PlayerStateNames.NONE


func _update_animation(is_moving: bool) -> void:
	if (
		player == null
		or player.animated_sprite == null
		or player.animated_sprite.sprite_frames == null
	):
		return

	if is_moving:
		animation_change_requested.emit(&"carry_move")
	else:
		animation_change_requested.emit(&"carry_idle")
