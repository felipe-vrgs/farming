extends NpcState

## Moving state - walks toward the order's target_position.
## Includes simple obstacle avoidance: when blocked, probes directions then sidesteps.

enum AvoidPhase {
	NONE,        # Not avoiding, moving normally
	WAITING,     # Blocked, waiting before trying to avoid
	SIDESTEPPING,# Moving to sidestep target
	GIVE_UP,     # Both directions blocked, just wait
}

## How long to wait before trying to go around (seconds)
const _WAIT_PLAYER := 0.8  # Player might move, wait a bit
const _WAIT_OBSTACLE := 0.2  # Walls won't move, try quickly

## How far to step sideways when avoiding (pixels)
const _SIDESTEP_DIST := 16.0

## How long to attempt sidestep before giving up on that direction (seconds)
const _SIDESTEP_TIMEOUT := 1.0

## Probe distance for checking if a direction is clear (pixels)
const _PROBE_DIST := 20.0

var _blocked_time: float = 0.0
var _avoid_phase: AvoidPhase = AvoidPhase.NONE
var _phase_time: float = 0.0
var _last_block_reason: AgentOrder.BlockReason = AgentOrder.BlockReason.NONE
var _original_target: Vector2 = Vector2.ZERO
var _sidestep_target: Vector2 = Vector2.ZERO

func enter() -> void:
	super.enter()
	_reset_avoidance()

func exit() -> void:
	_reset_avoidance()
	super.exit()

func _reset_avoidance() -> void:
	_blocked_time = 0.0
	_avoid_phase = AvoidPhase.NONE
	_phase_time = 0.0
	_last_block_reason = AgentOrder.BlockReason.NONE
	_original_target = Vector2.ZERO
	_sidestep_target = Vector2.ZERO

func process_physics(delta: float) -> StringName:
	if npc == null:
		return NPCStateNames.IDLE

	var order := _get_order()
	if order == null or order.action == AgentOrder.Action.IDLE:
		_reset_avoidance()
		return NPCStateNames.IDLE

	# Store original target for avoidance maneuvers
	if _original_target == Vector2.ZERO:
		_original_target = order.target_position

	# Determine current movement target
	var move_target := order.target_position
	if _avoid_phase == AvoidPhase.SIDESTEPPING:
		move_target = _sidestep_target

	var to_target := move_target - npc.global_position
	var dist := to_target.length()

	# Reached target?
	if dist <= _WAYPOINT_EPS:
		if _avoid_phase == AvoidPhase.SIDESTEPPING:
			# Completed sidestep, go back to normal movement
			_avoid_phase = AvoidPhase.NONE
			_phase_time = 0.0
			return NPCStateNames.NONE

		npc.velocity = Vector2.ZERO
		_reset_avoidance()
		_report_reached()
		return NPCStateNames.NONE

	var dir := to_target.normalized()
	var desired_velocity := dir * npc.move_speed
	var desired_motion := desired_velocity * delta

	# When sidestepping, be more aggressive - try to move even if player blocker is set
	# The physics engine (move_and_slide) will handle actual collisions
	if _avoid_phase == AvoidPhase.SIDESTEPPING:
		# Only stop for hard physics collisions, let move_and_slide handle sliding
		if would_collide_physics_only(desired_motion):
			# Check if we're making ANY progress
			npc.velocity = desired_velocity
			# After move_and_slide in _physics_process, check if actually stuck
			_phase_time += delta
			if _phase_time >= _SIDESTEP_TIMEOUT:
				_avoid_phase = AvoidPhase.GIVE_UP
				_phase_time = 0.0
				return _handle_blocked(delta, order)
			# Still try to move - might slide around
			request_animation_for_motion(npc.velocity)
			_report_moving()
			return NPCStateNames.NONE

		# Path clear, move normally
		npc.velocity = desired_velocity
		request_animation_for_motion(npc.velocity)
		if npc.footsteps_component and npc.velocity.length() > 0.1:
			npc.footsteps_component.play_footstep(delta)
		_report_moving()
		return NPCStateNames.NONE

	# Normal movement - check for blocks including player blocker area
	if would_collide(desired_motion):
		return _handle_blocked(delta, order)

	# Not blocked - move normally
	_blocked_time = 0.0
	_avoid_phase = AvoidPhase.NONE

	npc.velocity = desired_velocity
	request_animation_for_motion(npc.velocity)
	if npc.footsteps_component and npc.velocity.length() > 0.1:
		npc.footsteps_component.play_footstep(delta)

	_report_moving()
	return NPCStateNames.NONE

func _handle_blocked(delta: float, order: AgentOrder) -> StringName:
	var reason := _detect_block_reason()
	_last_block_reason = reason
	_blocked_time += delta
	_phase_time += delta

	npc.velocity = Vector2.ZERO
	request_animation_for_motion(Vector2.ZERO)
	if npc.footsteps_component:
		npc.footsteps_component.clear_timer()

	# State machine for avoidance
	match _avoid_phase:
		AvoidPhase.NONE:
			_avoid_phase = AvoidPhase.WAITING
			_phase_time = 0.0

		AvoidPhase.WAITING:
			var wait_time := _WAIT_PLAYER if reason == AgentOrder.BlockReason.PLAYER else _WAIT_OBSTACLE
			if _phase_time >= wait_time:
				_try_find_clear_direction(order.target_position)

		AvoidPhase.SIDESTEPPING:
			if _phase_time >= _SIDESTEP_TIMEOUT:
				# Sidestep timed out, try again
				_avoid_phase = AvoidPhase.GIVE_UP
				_phase_time = 0.0

		AvoidPhase.GIVE_UP:
			# Reset after a while to try again
			if _phase_time >= 1.5:
				_avoid_phase = AvoidPhase.WAITING
				_phase_time = 0.0

	_report_blocked(reason)
	return NPCStateNames.NONE


func _try_find_clear_direction(target: Vector2) -> void:
	if npc == null:
		_avoid_phase = AvoidPhase.GIVE_UP
		_phase_time = 0.0
		return

	var to_target := target - npc.global_position
	if to_target.length() < 0.1:
		_avoid_phase = AvoidPhase.GIVE_UP
		_phase_time = 0.0
		return

	var forward := to_target.normalized()
	var left := Vector2(-forward.y, forward.x)   # 90° CCW
	var right := Vector2(forward.y, -forward.x)  # 90° CW

	# Probe multiple angles to find a clear path
	# Start with diagonals (45°), then perpendicular (90°), then backward diagonals
	var directions: Array[Vector2] = [
		(forward + left).normalized(),        # 45° left-forward
		(forward + right).normalized(),       # 45° right-forward
		left,                                 # 90° left
		right,                                # 90° right
		(left - forward * 0.3).normalized(),  # ~110° left-back
		(right - forward * 0.3).normalized(), # ~110° right-back
		-forward,                             # 180° backward (last resort)
	]

	# Find first clear direction
	for dir in directions:
		if _probe_direction(dir):
			_sidestep_target = npc.global_position + dir * _SIDESTEP_DIST
			_avoid_phase = AvoidPhase.SIDESTEPPING
			_phase_time = 0.0
			return

	# All probes failed - if blocked by player, try to just pick a perpendicular direction anyway
	# The player might move, and at least the NPC will try something
	if npc.route_blocked_by_player:
		_sidestep_target = npc.global_position + left * _SIDESTEP_DIST
		_avoid_phase = AvoidPhase.SIDESTEPPING
		_phase_time = 0.0
		return

	# All directions blocked by walls
	_avoid_phase = AvoidPhase.GIVE_UP
	_phase_time = 0.0


func _probe_direction(dir: Vector2) -> bool:
	if npc == null:
		return false
	# Use physics-only check - ignore player blocker area for probing
	var motion := dir * _PROBE_DIST
	return not would_collide_physics_only(motion)

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
	status.blocked_duration = _blocked_time
	AgentBrain.report_status(status)

func _detect_block_reason() -> AgentOrder.BlockReason:
	if npc == null:
		return AgentOrder.BlockReason.OBSTACLE
	if npc.route_blocked_by_player:
		return AgentOrder.BlockReason.PLAYER
	return AgentOrder.BlockReason.OBSTACLE
