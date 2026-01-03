extends NpcState

## Moving state - walks toward the order's target_position.
## When blocked (player/obstacle), transitions to `Avoiding` state.

func process_physics(delta: float) -> StringName:
	if npc == null:
		return NPCStateNames.IDLE

	var order := _get_order()
	if order == null or order.action == AgentOrder.Action.IDLE:
		return NPCStateNames.IDLE

	var to_target := order.target_position - npc.global_position
	var dist := to_target.length()

	# Reached target?
	if dist <= get_waypoint_eps():
		npc.velocity = Vector2.ZERO
		request_animation_for_motion(Vector2.ZERO)
		if npc.footsteps_component:
			npc.footsteps_component.clear_timer()
		_report_reached()
		return NPCStateNames.NONE

	var dir := to_target.normalized()
	var desired_velocity := dir * npc.move_speed
	var desired_motion := desired_velocity * delta

	# Blocked? Hand off to Avoiding.
	if would_collide(desired_motion):
		# If the waypoint is basically underfoot but blocked by static geometry,
		# advance to the next waypoint instead of getting stuck.
		if dist <= get_waypoint_eps() * 1.5 and not npc.route_blocked_by_player:
			_report_reached()
			return NPCStateNames.NONE
		_report_blocked(_detect_block_reason(), 0.0)
		return NPCStateNames.AVOIDING

	npc.velocity = desired_velocity
	request_animation_for_motion(npc.velocity)
	if npc.footsteps_component and npc.velocity.length() > 0.1:
		npc.footsteps_component.play_footstep(delta)
	_report_moving()
	return NPCStateNames.NONE
