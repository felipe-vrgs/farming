extends NpcState

## TravelIntent state:
## - NPC is trying to reach a portal by following `npc.route_override_res` once.
## - Does not clear route intent when the route completes.
## - If blocked, just waits (deadline fallback commit is handled by AgentRegistry).

var _route: RouteResource = null
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
	var current_route := get_active_route()
	if current_level_id != _level_id or current_route != _route:
		_refresh_route()

	if _route == null or _waypoints.is_empty():
		npc.velocity = Vector2.ZERO
		request_animation_for_motion(Vector2.ZERO)
		return NPCStateNames.IDLE

	var target := _waypoints[_waypoint_idx]
	var to_target := target - npc.global_position
	if to_target.length() <= _WAYPOINT_EPS:
		# Reached waypoint.
		if _waypoint_idx >= _waypoints.size() - 1:
			# At end: wait here until the TravelZone commits travel.
			npc.velocity = Vector2.ZERO
			request_animation_for_motion(Vector2.ZERO)
			return NPCStateNames.NONE
		_waypoint_idx += 1
		target = _waypoints[_waypoint_idx]
		to_target = target - npc.global_position

	var dir := to_target.normalized()
	var desired_velocity := dir * npc.move_speed
	var desired_motion := desired_velocity * delta

	# If we'd collide, stop and wait (no bouncing state changes).
	if would_collide(desired_motion):
		npc.velocity = Vector2.ZERO
		request_animation_for_motion(Vector2.ZERO)
		return NPCStateNames.NONE

	npc.velocity = desired_velocity
	request_animation_for_motion(npc.velocity)
	return NPCStateNames.NONE

func _refresh_route() -> void:
	_level_id = get_active_level_id()
	_route = get_active_route()
	_waypoints = get_active_route_waypoints_global()
	if npc == null or _waypoints.is_empty():
		_waypoint_idx = 0
		return

	# Resume by targeting the *next* waypoint after the nearest one.
	var nearest := find_nearest_waypoint_index(_waypoints, npc.global_position)
	_waypoint_idx = (nearest + 1) % _waypoints.size()

