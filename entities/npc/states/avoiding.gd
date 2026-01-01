extends NpcState

## Avoiding state - encapsulates waiting + probing + sidestepping when blocked.
## Entered from Moving when the path is blocked (player or obstacle).
##
## Goal: keep NPCs moving without requiring player collision (no pushing).

enum AvoidPhase {
	WAITING,      # Blocked, waiting a bit before attempting a sidestep
	SIDESTEPPING, # Moving to a sidestep target
	GIVE_UP,      # Both directions blocked, wait then retry
}

## How long to wait before trying to go around (seconds)
const _WAIT_PLAYER := 0.8
const _WAIT_OBSTACLE := 0.2

## How far to step when avoiding (pixels)
const _SIDESTEP_DIST := 16.0

## How long to attempt a sidestep before giving up (seconds)
const _SIDESTEP_TIMEOUT := 1.0

## Probe distance for checking if a direction is clear (pixels)
const _PROBE_DIST := 20.0

## How long to keep a chosen avoid direction (seconds) to avoid jitter.
const _STEER_HOLD_TIME := 0.6

## How strongly to bias away from player when they block (0..1).
const _PLAYER_AVOID_WEIGHT := 0.8

var _phase: AvoidPhase = AvoidPhase.WAITING
var _phase_time: float = 0.0
var _blocked_time: float = 0.0
var _sidestep_target: Vector2 = Vector2.ZERO
var _steer_dir: Vector2 = Vector2.ZERO
var _steer_time_left: float = 0.0

func enter() -> void:
	super.enter()
	_phase = AvoidPhase.WAITING
	_phase_time = 0.0
	_blocked_time = 0.0
	_sidestep_target = Vector2.ZERO
	_steer_dir = Vector2.ZERO
	_steer_time_left = 0.0

func exit() -> void:
	_phase = AvoidPhase.WAITING
	_phase_time = 0.0
	_blocked_time = 0.0
	_sidestep_target = Vector2.ZERO
	_steer_dir = Vector2.ZERO
	_steer_time_left = 0.0
	super.exit()

func process_physics(delta: float) -> StringName:
	var next_state := NPCStateNames.NONE

	if npc == null:
		return NPCStateNames.IDLE

	var order := _get_order()
	if order == null or order.action == AgentOrder.Action.IDLE:
		_reset_motion()
		return NPCStateNames.IDLE

	# Cool down steer direction hold time (prevents jitter).
	_steer_time_left = maxf(0.0, _steer_time_left - delta)

	# If we are no longer blocked (player moved away + physics clear), return to Moving.
	if not npc.route_blocked_by_player:
		var to_goal := order.target_position - npc.global_position
		if to_goal.length() > _WAYPOINT_EPS:
			var desired_motion := to_goal.normalized() * npc.move_speed * delta
			if not would_collide(desired_motion):
				return NPCStateNames.MOVING

	# Determine current movement target
	var move_target := order.target_position
	if _phase == AvoidPhase.SIDESTEPPING and _sidestep_target != Vector2.ZERO:
		move_target = _sidestep_target

	var to_target := move_target - npc.global_position
	var dist := to_target.length()

	# Reached current target?
	if dist <= _WAYPOINT_EPS:
		if _phase == AvoidPhase.SIDESTEPPING:
			_phase_time = 0.0
			_sidestep_target = Vector2.ZERO
			# If player still blocking, immediately choose another sidestep and stay in Avoiding.
			if npc.route_blocked_by_player:
				_try_find_clear_direction(order.target_position)
				_report_blocked(_detect_block_reason(), _blocked_time)
			else:
				_steer_dir = Vector2.ZERO
				_steer_time_left = 0.0
				next_state = NPCStateNames.MOVING
		else:
			_reset_motion()
			_report_reached()
		return next_state

	# Update timers
	_phase_time += delta

	# If we're not sidestepping yet, count blocked time for reporting.
	if _phase != AvoidPhase.SIDESTEPPING:
		_blocked_time += delta

	match _phase:
		AvoidPhase.WAITING:
			_reset_motion()
			var reason := _detect_block_reason()
			var wait_time := _WAIT_PLAYER if reason == AgentOrder.BlockReason.PLAYER else _WAIT_OBSTACLE
			if _phase_time >= wait_time:
				_try_find_clear_direction(order.target_position)
			_report_blocked(reason, _blocked_time)

		AvoidPhase.SIDESTEPPING:
			# Keep pushing the sidestep target forward so we don't "arrive" immediately and oscillate.
			if _steer_dir != Vector2.ZERO:
				_sidestep_target = npc.global_position + _steer_dir * _SIDESTEP_DIST
				to_target = _sidestep_target - npc.global_position

			# Try to move toward sidestep target. Ignore player blocker area for physics checks.
			var dir := to_target.normalized()
			var desired_velocity := dir * npc.move_speed
			var desired_motion := desired_velocity * delta

			npc.velocity = desired_velocity
			request_animation_for_motion(npc.velocity)
			if npc.footsteps_component and npc.velocity.length() > 0.1:
				npc.footsteps_component.play_footstep(delta)
			_report_moving()

			# If we're colliding with geometry for too long, give up and retry.
			if would_collide_physics_only(desired_motion) and _phase_time >= _SIDESTEP_TIMEOUT:
				_phase = AvoidPhase.GIVE_UP
				_phase_time = 0.0
				_sidestep_target = Vector2.ZERO
				_steer_dir = Vector2.ZERO
				_steer_time_left = 0.0

		AvoidPhase.GIVE_UP:
			_reset_motion()
			_report_blocked(_detect_block_reason(), _blocked_time)
			if _phase_time >= 1.5:
				_phase = AvoidPhase.WAITING
				_phase_time = 0.0
				_blocked_time = 0.0
				_steer_dir = Vector2.ZERO
				_steer_time_left = 0.0

	return next_state

func _try_find_clear_direction(target: Vector2) -> void:
	if npc == null:
		_phase = AvoidPhase.GIVE_UP
		_phase_time = 0.0
		return

	var to_target := target - npc.global_position
	if to_target.length() < 0.1:
		_phase = AvoidPhase.GIVE_UP
		_phase_time = 0.0
		return

	var forward := to_target.normalized()
	var left := Vector2(-forward.y, forward.x)   # 90° CCW
	var right := Vector2(forward.y, -forward.x)  # 90° CW

	var away_from_player := Vector2.ZERO
	if npc.route_blocked_by_player and "get_player_blocker_away_dir" in npc:
		away_from_player = npc.get_player_blocker_away_dir()

	# Keep an existing steer direction for a short time to avoid oscillation.
	if _steer_time_left > 0.0 and _steer_dir != Vector2.ZERO:
		if _probe_direction(_steer_dir):
			_sidestep_target = npc.global_position + _steer_dir * _SIDESTEP_DIST
			_phase = AvoidPhase.SIDESTEPPING
			_phase_time = 0.0
			return

	# Build candidate steer directions.
	var candidates: Array[Vector2] = []

	# Player blocking: prioritize moving away + around (tangent) while still making some progress.
	if away_from_player != Vector2.ZERO:
		var tangent_l := Vector2(-away_from_player.y, away_from_player.x)
		var tangent_r := Vector2(away_from_player.y, -away_from_player.x)
		candidates.append(away_from_player)
		candidates.append((away_from_player + tangent_l * 0.75 + forward * 0.25).normalized())
		candidates.append((away_from_player + tangent_r * 0.75 + forward * 0.25).normalized())
		candidates.append((tangent_l + away_from_player * 0.5).normalized())
		candidates.append((tangent_r + away_from_player * 0.5).normalized())

	# General obstacle avoidance around the forward direction.
	candidates.append((forward + left).normalized())   # 45° left-forward
	candidates.append((forward + right).normalized())  # 45° right-forward
	candidates.append(left)                            # 90° left
	candidates.append(right)                           # 90° right
	candidates.append((left - forward * 0.3).normalized())
	candidates.append((right - forward * 0.3).normalized())
	candidates.append(-forward)

	# Pick best clear candidate by score (stable + makes progress + away from player).
	var best_dir := Vector2.ZERO
	var best_score := -INF
	for d in candidates:
		if d == Vector2.ZERO:
			continue
		if not _probe_direction(d):
			continue
		var score := d.dot(forward)
		if away_from_player != Vector2.ZERO:
			score = score * (1.0 - _PLAYER_AVOID_WEIGHT) + d.dot(away_from_player) * _PLAYER_AVOID_WEIGHT
		if score > best_score:
			best_score = score
			best_dir = d

	if best_dir != Vector2.ZERO:
		_steer_dir = best_dir
		_steer_time_left = _STEER_HOLD_TIME
		_sidestep_target = npc.global_position + best_dir * _SIDESTEP_DIST
		_phase = AvoidPhase.SIDESTEPPING
		_phase_time = 0.0
		return

	# All probes failed - if player is blocking, still pick left and try.
	if npc.route_blocked_by_player:
		_sidestep_target = npc.global_position + left * _SIDESTEP_DIST
		_phase = AvoidPhase.SIDESTEPPING
		_phase_time = 0.0
		_steer_dir = left
		_steer_time_left = _STEER_HOLD_TIME
		return

	_phase = AvoidPhase.GIVE_UP
	_phase_time = 0.0
	_steer_dir = Vector2.ZERO
	_steer_time_left = 0.0

func _probe_direction(dir: Vector2) -> bool:
	if npc == null:
		return false
	var motion := dir * _PROBE_DIST
	return not would_collide_physics_only(motion)
