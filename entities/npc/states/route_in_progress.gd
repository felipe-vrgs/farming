extends NpcState

var _route_id: RouteIds.Id = RouteIds.Id.NONE
var _waypoints: Array[Vector2] = []
var _waypoint_idx: int = 0
var _level_id: Enums.Levels = Enums.Levels.NONE

func enter() -> void:
	super.enter()
	_refresh_route()

func process_physics(delta: float) -> StringName:
	if npc == null:
		return NPCStateNames.IDLE

	# If route/level changes while we're alive, re-resolve.
	var current_level_id: Enums.Levels = get_active_level_id()
	var current_route_id: RouteIds.Id = get_active_route_id()
	if current_level_id != _level_id or current_route_id != _route_id:
		_refresh_route()

	if _route_id == RouteIds.Id.NONE or _waypoints.is_empty():
		npc.velocity = Vector2.ZERO
		request_animation_for_motion(Vector2.ZERO)
		return NPCStateNames.IDLE

	var target := _waypoints[_waypoint_idx]
	var to_target := target - npc.global_position
	if to_target.length() <= _WAYPOINT_EPS:
		_waypoint_idx = (_waypoint_idx + 1) % _waypoints.size()
		target = _waypoints[_waypoint_idx]
		to_target = target - npc.global_position

	var dir := to_target.normalized()
	var desired_velocity := dir * npc.move_speed
	var desired_motion := desired_velocity * delta

	# If we'd collide this frame, stop and wait.
	if would_collide(desired_motion):
		npc.velocity = Vector2.ZERO
		request_animation_for_motion(Vector2.ZERO)
		return NPCStateNames.ROUTE_BLOCKED

	npc.velocity = desired_velocity
	request_animation_for_motion(npc.velocity)
	return NPCStateNames.NONE

func _refresh_route() -> void:
	_level_id = get_active_level_id()
	_route_id = get_active_route_id()
	_waypoints = get_active_route_waypoints_global()
	if npc == null or _waypoints.is_empty():
		_waypoint_idx = 0
		return

	# Resume by targeting the *next* waypoint after the nearest one.
	# This feels cleaner than snapping back to the nearest marker.
	var nearest := find_nearest_waypoint_index(_waypoints, npc.global_position)
	_waypoint_idx = (nearest + 1) % _waypoints.size()

