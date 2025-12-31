extends NpcState

var _waypoints: Array[Vector2] = []
var _waypoint_idx: int = 0

func enter() -> void:
	super.enter()
	if npc == null:
		return
	npc.velocity = Vector2.ZERO
	request_animation_for_motion(Vector2.ZERO)

func process_physics(delta: float) -> StringName:
	if npc == null:
		return NPCStateNames.IDLE

	# If we no longer have a route, fall back to idle.
	if get_active_route_id() == RouteIds.Id.NONE:
		npc.velocity = Vector2.ZERO
		request_animation_for_motion(Vector2.ZERO)
		return NPCStateNames.IDLE

	# Recompute route context (cheap for MVP; can be cached later).
	_waypoints = get_active_route_waypoints_global()
	_waypoint_idx = find_nearest_waypoint_index(_waypoints, npc.global_position)
	if _waypoints.is_empty():
		npc.velocity = Vector2.ZERO
		request_animation_for_motion(Vector2.ZERO)
		return NPCStateNames.IDLE

	var target := _waypoints[_waypoint_idx]
	var to_target := target - npc.global_position
	if to_target.length() <= _WAYPOINT_EPS:
		_waypoint_idx = (_waypoint_idx + 1) % _waypoints.size()
		target = _waypoints[_waypoint_idx]
		to_target = target - npc.global_position

	var desired_velocity := to_target.normalized() * npc.move_speed
	var desired_motion := desired_velocity * delta

	# If the next move would not collide, resume following.
	if not would_collide(desired_motion):
		return NPCStateNames.ROUTE_IN_PROGRESS

	# Still blocked: stay idle-in-place.
	npc.velocity = Vector2.ZERO
	request_animation_for_motion(Vector2.ZERO)
	return NPCStateNames.NONE

