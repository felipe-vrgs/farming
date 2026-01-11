extends PlayerState

# TOOL_CHARGING state
# - Plays the "prepare" or idle frame of the tool animation (or special charge animation)
# - Waits for release to transition to TOOL_SWING
# - Could add charge meter logic here later


func enter() -> void:
	if player:
		player.velocity = Vector2.ZERO
		# If tool doesn't have charge capability, transition immediately
		if player.tool_node.data and not player.tool_node.data.has_charge:
			# We can't transition immediately in enter(), so we handle it in process_frame or input
			pass

		var anim_base = _compute_body_animation_base()
		if not String(anim_base).is_empty():
			animation_change_requested.emit(anim_base)
			# Freeze the pose only for actual charge tools.
			if (
				player.animated_sprite
				and player.tool_node.data
				and player.tool_node.data.has_charge
			):
				player.animated_sprite.speed_scale = 0.0
		# Freeze tool sprite pose (so tool + body stay aligned while charging).
		if (
			player.tool_node != null
			and player.tool_node.data != null
			and player.tool_node.data.has_charge
			and player.raycell_component != null
		):
			if player.tool_node.has_method("show_tool_pose"):
				player.tool_node.call("show_tool_pose", player.raycell_component.facing_dir)


func exit() -> void:
	if player and player.animated_sprite:
		player.animated_sprite.speed_scale = 1.0
	if player and player.tool_node and player.tool_node.has_method("hide_tool"):
		player.tool_node.call("hide_tool")


func process_frame(_delta: float) -> StringName:
	# Immediate transition if no charge supported
	if player and player.tool_node.data and not player.tool_node.data.has_charge:
		return PlayerStateNames.TOOL_SWING
	return PlayerStateNames.NONE


func process_input(event: InputEvent) -> StringName:
	if player and player.player_input_config:
		if event.is_action_released(player.player_input_config.action_interact):
			return PlayerStateNames.TOOL_SWING
	return PlayerStateNames.NONE


func process_physics(_delta: float) -> StringName:
	return PlayerStateNames.NONE


func _compute_tool_animation_base() -> StringName:
	if player == null or player.tool_node.data == null:
		return &""
	var prefix := player.tool_node.data.animation_prefix
	if String(prefix).is_empty():
		return &""
	return prefix


func _compute_body_animation_base() -> StringName:
	if player == null or player.tool_node == null or player.tool_node.data == null:
		return &""
	var base: StringName = player.tool_node.data.player_body_anim
	if not String(base).is_empty():
		return base
	# Back-compat fallback.
	var kind: Enums.ToolActionKind = player.tool_node.data.action_kind
	return &"player_use" if kind == Enums.ToolActionKind.WATER else &"player_swing"
