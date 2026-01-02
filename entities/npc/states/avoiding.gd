extends NpcState

## Avoiding state - Reactive steering behavior (Seek + Avoid).
## Entered from Moving when the path is blocked (player or obstacle).
##
## Goal: Fluidly steer around obstacles and players without stopping.
enum Mode {
	SEEK = 0,
	FOLLOW_WALL = 1,
}

# Steering weights (top-down: 2D vectors, not axis locked)
const _W_SEEK := 1.0
const _W_AVOID_PLAYER := 2.5

# Bug2-style wall-follow parameters
const _PROBE_DIST := 18.0
const _WALL_PUSH := 0.85
const _SMOOTHING := 14.0 # Higher = more responsive

const _STUCK_TIME_THRESHOLD := 2.0
const _STUCK_VELOCITY_THRESHOLD := 5.0

const _LEAVE_WALL_MARGIN := 6.0

var _mode: Mode = Mode.SEEK
var _hit_goal_dist: float = INF
var _follow_sign: float = 1.0
var _follow_dir: Vector2 = Vector2.ZERO
var _last_wall_normal: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0

func enter() -> void:
	super.enter()
	_stuck_timer = 0.0
	_mode = Mode.SEEK
	_hit_goal_dist = INF
	_follow_sign = 1.0
	_follow_dir = Vector2.ZERO
	_last_wall_normal = Vector2.ZERO
	_report_blocked(_detect_block_reason(), 0.0)

func exit() -> void:
	_stuck_timer = 0.0
	_mode = Mode.SEEK
	_hit_goal_dist = INF
	_follow_dir = Vector2.ZERO
	_last_wall_normal = Vector2.ZERO
	super.exit()

func process_physics(delta: float) -> StringName:
	var next_state := NPCStateNames.NONE

	if npc == null:
		return NPCStateNames.IDLE

	var order := _get_order()
	if order == null or order.action == AgentOrder.Action.IDLE:
		_reset_motion()
		return NPCStateNames.IDLE

	var target_pos := order.target_position
	var to_target := target_pos - npc.global_position
	var dist := to_target.length()

	# Reached target?
	if dist <= _WAYPOINT_EPS:
		_reset_motion()
		_report_reached()
		return NPCStateNames.NONE

	var seek_dir := to_target.normalized()

	# Player avoidance (only when overlap says player is near)
	var avoid_player_dir := Vector2.ZERO
	if npc.route_blocked_by_player:
		var away := Vector2.ZERO
		if "get_player_blocker_away_dir" in npc:
			away = npc.get_player_blocker_away_dir()
		if away == Vector2.ZERO:
			away = -npc.facing_dir if npc.facing_dir != Vector2.ZERO else Vector2.RIGHT
		# Prefer sidestep around player instead of backing up.
		var tangent_p := Vector2(-away.y, away.x)
		if (-tangent_p).dot(seek_dir) > tangent_p.dot(seek_dir):
			tangent_p = -tangent_p
		avoid_player_dir = (away * 0.35 + tangent_p).normalized()

	# --- Bug2 controller ---
	# SEEK: move toward goal until we detect an obstacle in front.
	# FOLLOW_WALL: follow obstacle boundary (stable side) until line-of-sight to goal is clear
	# and we're closer to goal than when we first hit the obstacle.
	var desired_dir := seek_dir

	if _mode == Mode.SEEK:
		var hit := npc.move_and_collide(seek_dir * _PROBE_DIST, true)
		if hit:
			_mode = Mode.FOLLOW_WALL
			_hit_goal_dist = dist
			_last_wall_normal = hit.get_normal()

			var tangent := Vector2(-_last_wall_normal.y, _last_wall_normal.x)
			_follow_sign = 1.0 if tangent.dot(seek_dir) >= (-tangent).dot(seek_dir) else -1.0
			_follow_dir = tangent * _follow_sign

			# Start by moving along the wall immediately.
			desired_dir = (_follow_dir + _last_wall_normal * _WALL_PUSH).normalized()
	elif _mode == Mode.FOLLOW_WALL:
		# Keep a contact normal by probing in our current follow direction.
		var follow := _follow_dir
		if follow.length() < 0.1:
			follow = Vector2(-seek_dir.y, seek_dir.x) * _follow_sign

		var hit_f := npc.move_and_collide(follow.normalized() * _PROBE_DIST, true)
		if hit_f:
			_last_wall_normal = hit_f.get_normal()
			var tangent2 := Vector2(-_last_wall_normal.y, _last_wall_normal.x) * _follow_sign
			_follow_dir = tangent2.normalized()

		# Desired direction is to move along wall + slightly away from it.
		if _last_wall_normal != Vector2.ZERO:
			desired_dir = (_follow_dir + _last_wall_normal * _WALL_PUSH).normalized()
		else:
			desired_dir = _follow_dir

		# Leave condition: clear line to goal AND we made progress vs hit point.
		var space_state := npc.get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(npc.global_position, target_pos)
		query.exclude = [npc.get_rid()]
		var ray := space_state.intersect_ray(query)
		var has_line_of_sight := ray.is_empty()
		if has_line_of_sight and dist <= _hit_goal_dist - _LEAVE_WALL_MARGIN:
			_mode = Mode.SEEK
			_last_wall_normal = Vector2.ZERO

	# Combine desired_dir with player avoidance (still allows up/down/diagonals)
	var final_dir := (desired_dir * _W_SEEK)
	if avoid_player_dir != Vector2.ZERO:
		final_dir += avoid_player_dir * _W_AVOID_PLAYER
	if final_dir.length() > 0.001:
		final_dir = final_dir.normalized()
	else:
		final_dir = desired_dir

	var target_vel := final_dir * npc.move_speed
	npc.velocity = npc.velocity.lerp(target_vel, _SMOOTHING * delta)

	request_animation_for_motion(npc.velocity)
	if npc.footsteps_component and npc.velocity.length() > 0.1:
		npc.footsteps_component.play_footstep(delta)

	_report_moving()

	# --- Exit Conditions / Stuck Check ---
	# 1. Stuck Check
	if npc.velocity.length() < _STUCK_VELOCITY_THRESHOLD:
		_stuck_timer += delta
	else:
		_stuck_timer = maxf(0.0, _stuck_timer - delta)

	if _stuck_timer > _STUCK_TIME_THRESHOLD:
		# We are stuck. Report blocked and flip follow side to break symmetry.
		_report_blocked(_detect_block_reason(), _stuck_timer)
		_follow_sign *= -1.0
		_follow_dir = Vector2(-_follow_dir.x, -_follow_dir.y)
		_mode = Mode.FOLLOW_WALL
		_stuck_timer = 0.0 # Reset to give it a chance

	# If wall-follow resolved and player isn't blocking, hand control back to Moving.
	# (Moving will immediately re-enter Avoiding if it still collides.)
	if _mode == Mode.SEEK and not npc.route_blocked_by_player:
		var desired_motion := seek_dir * npc.move_speed * delta
		if not would_collide(desired_motion):
			return NPCStateNames.MOVING

	return next_state
