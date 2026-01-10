extends PlayerState

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

	if player and player.tool_node.data:
		player.velocity = Vector2.ZERO

		# Play animation
		var anim_base = _compute_tool_animation_base()
		if not String(anim_base).is_empty():
			animation_change_requested.emit(anim_base)
			# Ensure it plays from start
			if player.animated_sprite:
				player.animated_sprite.stop()
				player.animated_sprite.play()

		# Delegate swing visuals and sound to tool node
		if player.tool_node:
			player.tool_node.play_swing(player.tool_node.data, player.raycell_component.facing_dir)

		# Cache target cell
		if player.raycell_component:
			_target_cell = player.raycell_component.get_front_cell()


func exit() -> void:
	if player:
		if player.tool_node:
			player.tool_node.stop_swish()
		# Start cooldown on exit
		player.tool_manager.start_tool_cooldown()


func process_frame(delta: float) -> StringName:
	if player == null or player.tool_node.data == null:
		return PlayerStateNames.IDLE

	_elapsed += delta
	var duration = player.tool_node.data.use_duration
	if not _did_apply:
		if _elapsed >= duration * 0.3:
			_did_apply = true
			_perform_action()

	if _elapsed >= duration:
		return PlayerStateNames.IDLE

	return PlayerStateNames.NONE


func _perform_action() -> void:
	if _target_cell != null and player.tool_node.data:
		var tool: ToolData = player.tool_node.data
		var energy := player.energy_component if ("energy_component" in player) else null

		# Hybrid energy drain: attempt + (optional) success cost.
		if energy != null and is_instance_valid(energy) and tool.energy_cost_attempt > 0.0:
			if energy.has_method("spend_attempt"):
				energy.call("spend_attempt", float(tool.energy_cost_attempt))

		_success = tool.try_use(_target_cell as Vector2i, player)

		if (
			_success
			and energy != null
			and is_instance_valid(energy)
			and tool.energy_cost_success > 0.0
		):
			if energy.has_method("spend_success"):
				energy.call("spend_success", float(tool.energy_cost_success))

		# Visual feedback (Juice)
		if _success:
			if player.tool_node.data.player_recoil:
				player.recoil()

			if player.tool_node:
				player.tool_node.on_success()
		else:
			# On failure, stop the animation early
			if player.animated_sprite:
				player.animated_sprite.stop()

			if player.tool_node:
				player.tool_node.on_failure()


func _compute_tool_animation_base() -> StringName:
	var prefix := player.tool_node.data.animation_prefix
	if String(prefix).is_empty():
		return &""
	return prefix
