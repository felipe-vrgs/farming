extends PlayerState


func enter() -> void:
	super.enter()
	animation_change_requested.emit(PlayerStateNames.IDLE)


func process_input(event: InputEvent) -> StringName:
	if player and player.player_input_config:
		if event.is_action_pressed(player.player_input_config.action_interact):
			if player.tool_manager.can_use_tool():
				# Stardew-like hard blockers (NPC / harvest) should not start tool animation at all.
				if player.raycell_component != null and WorldGrid != null:
					var v: Variant = player.raycell_component.get_front_cell()
					if v is Vector2i and WorldGrid.try_resolve_tool_press(player, v as Vector2i):
						player.tool_manager.start_tool_cooldown()
						return PlayerStateNames.NONE
				# If we're carrying an item (non-tool), use placement logic instead of tool swing.
				if player.tool_manager != null:
					if player.tool_manager.is_in_item_mode():
						return PlayerStateNames.PLACEMENT
				# Tool action.
				if player.tool_node != null and player.tool_node.data != null:
					return PlayerStateNames.TOOL_CHARGING
		if event.is_action_pressed(player.player_input_config.action_use):
			return PlayerStateNames.USE
	return PlayerStateNames.NONE


func process_physics(delta: float) -> StringName:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		return PlayerStateNames.WALK

	# Apply friction
	if player and player_balance_config:
		var friction = player_balance_config.friction * delta
		player.velocity = player.velocity.move_toward(Vector2.ZERO, friction)

	return PlayerStateNames.NONE
