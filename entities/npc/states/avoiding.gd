extends NpcState

## Avoiding state - simple steer with sampling and debug lines.
## - Probe forward; if blocked, sample rotated directions toward the target.
## - Player bias: away + tangent.
## - If stuck for a while, advance waypoint (report reached) to avoid loops.

const _PROBE_DIST := 24.0
const _SMOOTHING := 5.0
const _STUCK_TIME := 4.0
const _MIN_VEL := 4.0
const _STEER_ANGLES := [
	deg_to_rad(10),
	deg_to_rad(20),
	deg_to_rad(30),
	deg_to_rad(45),
	deg_to_rad(60),
	deg_to_rad(80),
	deg_to_rad(110),
	deg_to_rad(140),
	deg_to_rad(170),
]

var _stuck_timer: float = 0.0
var _last_dist: float = INF
var _last_avoid_sign: float = 0.0 # -1 or +1 bias
var _debug_target: Line2D
var _debug_forward: Line2D
var _debug_chosen: Line2D

func enter() -> void:
	super.enter()
	_stuck_timer = 0.0
	_last_dist = INF
	_last_avoid_sign = 0.0
	_ensure_debug_lines()
	_report_blocked(_detect_block_reason(), 0.0)

func exit() -> void:
	_stuck_timer = 0.0
	_last_dist = INF
	_last_avoid_sign = 0.0
	_clear_debug()
	super.exit()

func process_physics(delta: float) -> StringName:
	if npc == null:
		return NPCStateNames.IDLE

	var order := _get_order()
	if order == null or order.action == AgentOrder.Action.IDLE:
		_reset_motion()
		return NPCStateNames.IDLE

	var target_pos := order.target_position
	var to_target := target_pos - npc.global_position
	var dist := to_target.length()

	if dist <= _WAYPOINT_EPS:
		_reset_motion()
		_report_reached()
		return NPCStateNames.NONE

	var seek_dir := to_target.normalized()
	var desired_dir := seek_dir
	var chosen_dir := seek_dir

	chosen_dir = _pick_direction(seek_dir)
	desired_dir = chosen_dir

	# If blocked by player, blend in the "away" vector to maintain separation.
	# We rely on _is_blocked_dir (called by _pick_direction) to filter out paths into the player.
	if npc.route_blocked_by_player:
		var away := Vector2.ZERO
		if npc.has_method("get_player_blocker_away_dir"):
			away = npc.get_player_blocker_away_dir()
		if away != Vector2.ZERO:
			desired_dir = (desired_dir + away * 0.8).normalized()
	if desired_dir == Vector2.ZERO:
		# If we found no valid direction, stop rather than pushing into the wall.
		pass

	var target_vel := desired_dir * npc.move_speed
	npc.velocity = npc.velocity.lerp(target_vel, _SMOOTHING * delta)

	request_animation_for_motion(npc.velocity)
	if npc.footsteps_component and npc.velocity.length() > 0.1:
		npc.footsteps_component.play_footstep(delta)

	if npc.velocity.length() < _MIN_VEL:
		_report_blocked(_detect_block_reason(), _stuck_timer)
	else:
		_report_moving()

	_update_debug(target_pos, seek_dir, chosen_dir)
	# "Stuck" means not making progress toward the target.
	if dist >= _last_dist - 0.25:
		_stuck_timer += delta
	else:
		_stuck_timer = maxf(0.0, _stuck_timer - delta * 2.0)
	_last_dist = dist

	if _stuck_timer > _STUCK_TIME:
		_report_reached()
		_stuck_timer = 0.0
		return NPCStateNames.NONE

	return NPCStateNames.NONE

func _pick_direction(seek_dir: Vector2) -> Vector2:
	var result := Vector2.ZERO

	# 1. Try straight ahead first
	if not _is_blocked_dir(seek_dir):
		# Only reset bias if we are very confident or far from obstacles.
		# If we reset too eagerly, we might flicker.
		# For now, let's reset but maybe consider keeping it if "near" obstacle.
		# _last_avoid_sign = 0.0 # DISABLED: Keep bias to prevent snapping on intermittent clear paths.
		result = seek_dir

	# 2. If we have a bias, exhaust that side completely first.
	if result == Vector2.ZERO and _last_avoid_sign != 0.0:
		result = _check_angles(_last_avoid_sign, seek_dir)

		# If preferred side failed, try the other side (full sweep)
		if result == Vector2.ZERO:
			var other_sign := -_last_avoid_sign
			var alt := _check_angles(other_sign, seek_dir)
			if alt != Vector2.ZERO:
				_last_avoid_sign = other_sign
				result = alt

	# 3. No bias (or reset): use raycasts to find which side is more open ("whisker" scan)
	if result == Vector2.ZERO:
		var a_sign := _evaluate_obstacle_side(seek_dir)
		if a_sign != 0.0:
			_last_avoid_sign = a_sign
			result = _check_angles(a_sign, seek_dir)

	# 4. Fallback: check alternating if smart pick failed or returned 0
	if result == Vector2.ZERO:
		for angle in _STEER_ANGLES:
			# Try positive first (arbitrary, could be random)
			var dir_pos := seek_dir.rotated(angle)
			if not _is_blocked_dir(dir_pos):
				_last_avoid_sign = 1.0
				result = dir_pos.normalized()
				break

			var dir_neg := seek_dir.rotated(-angle)
			if not _is_blocked_dir(dir_neg):
				_last_avoid_sign = -1.0
				result = dir_neg.normalized()
				break

	return result

func _check_angles(a_sign: float, seek_dir: Vector2) -> Vector2:
	for angle in _STEER_ANGLES:
		var test_angle = angle * a_sign
		var dir := seek_dir.rotated(test_angle)
		if not _is_blocked_dir(dir):
			return dir.normalized()
	return Vector2.ZERO

func _evaluate_obstacle_side(seek_dir: Vector2) -> float:
	# Cast rays at wide angles to detect which side has more space
	# Returns 1.0 for Left preference, -1.0 for Right, 0.0 for unknown
	var result := 0.0
	if npc == null:
		return result

	var space := npc.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.new()
	q.exclude = [npc.get_rid()]
	q.collision_mask = npc.collision_mask
	q.hit_from_inside = false

	# Check +/- 45 degrees
	var ray_len := _PROBE_DIST * 1.5

	# Left ray (+45)
	q.from = npc.global_position
	q.to = npc.global_position + seek_dir.rotated(deg_to_rad(45)) * ray_len
	var hit_left := space.intersect_ray(q)

	# Right ray (-45)
	q.from = npc.global_position
	q.to = npc.global_position + seek_dir.rotated(deg_to_rad(-45)) * ray_len
	var hit_right := space.intersect_ray(q)

	# Prefer the "nearer edge" so the NPC hugs corners instead of taking wide arcs.
	# - If only one side hits, prefer that side (it has a nearby wall/edge).
	# - If both hit, prefer the smaller distance (closer obstacle).
	# - If neither hits, don't bias.
	var left_empty := hit_left.is_empty()
	var right_empty := hit_right.is_empty()
	if left_empty and right_empty:
		result = 0.0
	elif not left_empty and right_empty:
		result = 1.0
	elif left_empty and not right_empty:
		result = -1.0
	else:
		var dist_left := npc.global_position.distance_to(hit_left.position)
		var dist_right := npc.global_position.distance_to(hit_right.position)
		if is_equal_approx(dist_left, dist_right):
			result = 0.0
		elif dist_left < dist_right:
			result = 1.0
		else:
			result = -1.0

	return result

func _is_blocked_dir(dir: Vector2) -> bool:
	if npc == null:
		return false
	# Check player blockage first (soft block) to prevent walking into/through player.
	if npc.route_blocked_by_player:
		var away := Vector2.ZERO
		if npc.has_method("get_player_blocker_away_dir"):
			away = npc.get_player_blocker_away_dir()
		if away != Vector2.ZERO and dir.dot(away) < -0.6:
			return true

	# Kinematic test_move checks the full shape sweep.
	return npc.test_move(npc.global_transform, dir * _PROBE_DIST)

func _ensure_debug_lines() -> void:
	if npc == null or not npc.debug_avoidance:
		return
	if _debug_target == null or not is_instance_valid(_debug_target):
		_debug_target = Line2D.new()
		_debug_target.name = "AvoidTarget"
		_debug_target.width = 1.5
		# Red line points to actual target position.
		_debug_target.default_color = Color.RED
		_debug_target.z_index = 1000
		npc.add_child(_debug_target)
	if _debug_forward == null or not is_instance_valid(_debug_forward):
		_debug_forward = Line2D.new()
		_debug_forward.name = "AvoidForward"
		_debug_forward.width = 1.5
		# Green line is the forward probe direction.
		_debug_forward.default_color = Color.GREEN
		_debug_forward.z_index = 1000
		npc.add_child(_debug_forward)
	if _debug_chosen == null or not is_instance_valid(_debug_chosen):
		_debug_chosen = Line2D.new()
		_debug_chosen.name = "AvoidChosen"
		_debug_chosen.width = 1.5
		_debug_chosen.default_color = Color.YELLOW
		_debug_chosen.z_index = 1000
		npc.add_child(_debug_chosen)

func _update_debug(target_pos: Vector2, seek_dir: Vector2, chosen_dir: Vector2) -> void:
	if npc == null or not npc.debug_avoidance:
		_clear_debug()
		return
	_ensure_debug_lines()
	if _debug_target != null and is_instance_valid(_debug_target):
		_debug_target.points = PackedVector2Array([Vector2.ZERO, npc.to_local(target_pos)])
	if _debug_forward != null and is_instance_valid(_debug_forward):
		_debug_forward.points = PackedVector2Array([Vector2.ZERO, seek_dir * _PROBE_DIST])
	if _debug_chosen != null and is_instance_valid(_debug_chosen):
		_debug_chosen.points = PackedVector2Array([Vector2.ZERO, chosen_dir * _PROBE_DIST])

func _clear_debug() -> void:
	if _debug_target != null and is_instance_valid(_debug_target):
		_debug_target.queue_free()
	if _debug_forward != null and is_instance_valid(_debug_forward):
		_debug_forward.queue_free()
	if _debug_chosen != null and is_instance_valid(_debug_chosen):
		_debug_chosen.queue_free()
	_debug_target = null
	_debug_forward = null
	_debug_chosen = null
