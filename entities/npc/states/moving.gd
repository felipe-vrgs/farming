extends NpcState

## Moving state - walks toward the order's target_position.

func enter() -> void:
	super.enter()

func process_physics(delta: float) -> StringName:
	if npc == null:
		return NPCStateNames.IDLE

	var order := _get_order()
	if order == null or order.action == AgentOrder.Action.IDLE:
		return NPCStateNames.IDLE

	var to_target := order.target_position - npc.global_position
	var dist := to_target.length()

	# Reached target?
	if dist <= _WAYPOINT_EPS:
		npc.velocity = Vector2.ZERO
		_report_reached()
		return NPCStateNames.NONE

	var dir := to_target.normalized()
	var desired_velocity := dir * npc.move_speed
	var desired_motion := desired_velocity * delta

	# Check for collision
	if would_collide(desired_motion):
		npc.velocity = Vector2.ZERO
		request_animation_for_motion(Vector2.ZERO)
		_report_blocked(_detect_block_reason())
		if npc.footsteps_component:
			npc.footsteps_component.clear_timer()
		return NPCStateNames.NONE

	npc.velocity = desired_velocity
	request_animation_for_motion(npc.velocity)
	if npc.footsteps_component and npc.velocity.length() > 0.1:
		npc.footsteps_component.play_footstep(delta)

	_report_moving()
	return NPCStateNames.NONE

func _get_order() -> AgentOrder:
	if AgentBrain == null or npc == null or npc.agent_component == null:
		return null
	return AgentBrain.get_order(npc.agent_component.agent_id)

func _report_reached() -> void:
	if AgentBrain == null or npc == null or npc.agent_component == null:
		return
	var status := AgentStatus.new()
	status.agent_id = npc.agent_component.agent_id
	status.position = npc.global_position
	status.reached_target = true
	AgentBrain.report_status(status)

func _report_moving() -> void:
	if AgentBrain == null or npc == null or npc.agent_component == null:
		return
	var status := AgentStatus.new()
	status.agent_id = npc.agent_component.agent_id
	status.position = npc.global_position
	status.reached_target = false
	AgentBrain.report_status(status)

func _report_blocked(reason: AgentOrder.BlockReason) -> void:
	if AgentBrain == null or npc == null or npc.agent_component == null:
		return
	var status := AgentStatus.new()
	status.agent_id = npc.agent_component.agent_id
	status.position = npc.global_position
	status.reached_target = false
	status.is_blocked = true
	status.block_reason = reason
	AgentBrain.report_status(status)

func _detect_block_reason() -> AgentOrder.BlockReason:
	if npc == null:
		return AgentOrder.BlockReason.OBSTACLE
	if npc.route_blocked_by_player:
		return AgentOrder.BlockReason.PLAYER
	return AgentOrder.BlockReason.OBSTACLE
