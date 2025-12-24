extends State

# TOOL_CHARGING state
# - Plays the "prepare" or idle frame of the tool animation (or special charge animation)
# - Waits for release to transition to TOOL_SWING
# - Could add charge meter logic here later

func enter() -> void:
	if parent:
		parent.velocity = Vector2.ZERO
		# If tool doesn't have charge capability, transition immediately
		if parent.tool_node.data and not parent.tool_node.data.has_charge:
			# We can't transition immediately in enter(), so we handle it in process_frame or input
			pass

		var anim_base = _compute_tool_animation_base()
		if not String(anim_base).is_empty():
			animation_change_requested.emit(anim_base)
			if parent.animated_sprite:
				parent.animated_sprite.speed_scale = 0.0

func exit() -> void:
	if parent and parent.animated_sprite:
		parent.animated_sprite.speed_scale = 1.0

func process_frame(_delta: float) -> StringName:
	# Immediate transition if no charge supported
	if parent and parent.tool_node.data and not parent.tool_node.data.has_charge:
		return PlayerStateNames.TOOL_SWING
	return PlayerStateNames.NONE

func process_input(event: InputEvent) -> StringName:
	if parent and parent.player_input_config:
		if event.is_action_released(parent.player_input_config.action_interact):
			return PlayerStateNames.TOOL_SWING
	return PlayerStateNames.NONE

func process_physics(_delta: float) -> StringName:
	return PlayerStateNames.NONE

func _compute_tool_animation_base() -> StringName:
	if parent == null or parent.tool_node.data == null:
		return &""
	var prefix := parent.tool_node.data.animation_prefix
	if String(prefix).is_empty():
		return &""
	return prefix
