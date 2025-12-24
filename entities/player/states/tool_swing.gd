extends State

# TOOL_SWING state
# - Plays the tool animation
# - Applies the effect at the right moment (mid-animation or specific frame)
# - Transitions back to IDLE when done

var _elapsed: float = 0.0
var _did_apply: bool = false
var _target_cell: Variant = null
var _success: bool = false

func enter() -> void:
	_elapsed = 0.0
	_did_apply = false
	_success = false
	_target_cell = null

	if parent and parent.tool_node.data:
		parent.velocity = Vector2.ZERO

		# Play animation
		var anim_base = _compute_tool_animation_base()
		if not String(anim_base).is_empty():
			animation_change_requested.emit(anim_base)
			# Ensure it plays from start
			if parent.animated_sprite:
				parent.animated_sprite.stop()
				parent.animated_sprite.play()

		# Delegate swing visuals and sound to tool node
		if parent.tool_node:
			parent.tool_node.play_swing(parent.tool_node.data, parent.interactivity_manager.facing_dir)

		# Cache target cell
		if parent.interactivity_manager:
			_target_cell = parent.interactivity_manager.get_front_cell(parent)

func exit() -> void:
	if parent and parent.tool_node:
		parent.tool_node.stop_swish()

func process_frame(delta: float) -> StringName:
	if parent == null or parent.tool_node.data == null:
		return PlayerStateNames.IDLE

	_elapsed += delta
	var duration = parent.tool_node.data.use_duration
	# Apply effect
	if not _did_apply:
		# Apply at 50% or check if there's a specific timing in ToolData
		if _elapsed >= duration * 0.5:
			_did_apply = true
			_perform_action()

	if _elapsed >= duration:
		return PlayerStateNames.IDLE

	return PlayerStateNames.NONE

func _perform_action() -> void:
	if _target_cell != null and parent.tool_node.data:
		_success = parent.tool_node.data.try_use(parent, _target_cell as Vector2i)

		# Visual feedback (Juice)
		if _success:
			if parent.tool_node.data.player_recoil and parent.shake_component:
				parent.shake_component.start_shake()

			if parent.tool_node:
				parent.tool_node.play_success()
		else:
			# On failure, stop the animation early
			if parent.animated_sprite:
				parent.animated_sprite.stop()

			if parent.tool_node:
				parent.tool_node.play_fail()

func _compute_tool_animation_base() -> StringName:
	var prefix := parent.tool_node.data.animation_prefix
	if String(prefix).is_empty():
		return &""
	return prefix
