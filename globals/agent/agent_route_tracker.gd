class_name AgentRouteTracker
extends RefCounted

## AgentRouteTracker - manages route progress for a single agent.
##
## Tracks which route the agent is on, which waypoint they're targeting,
## and provides the next waypoint when the current one is reached.

const _WAYPOINT_REACHED_EPS := 2.0

var agent_id: StringName = &""
var route_key: StringName = &""
var waypoints: Array[Vector2] = []
var waypoint_idx: int = 0
var is_looping: bool = true
var is_travel_route: bool = false  ## True if walking to a portal

var _completed: bool = false  ## True if non-looping route finished


func reset() -> void:
	route_key = &""
	waypoints.clear()
	waypoint_idx = 0
	is_looping = true
	is_travel_route = false
	_completed = false


func is_active() -> bool:
	return not waypoints.is_empty() and not _completed


func get_current_target() -> Vector2:
	if waypoints.is_empty() or _completed:
		return Vector2.ZERO
	return waypoints[clampi(waypoint_idx, 0, waypoints.size() - 1)]


func get_progress() -> float:
	if waypoints.is_empty():
		return 0.0
	return float(waypoint_idx) / float(max(1, waypoints.size()))


## Initialize or switch to a new route.
## Returns true if route was changed.
func set_route(
	new_route_key: StringName,
	new_waypoints: Array[Vector2],
	current_pos: Vector2,
	looping: bool,
	travel: bool
) -> bool:
	if new_route_key == route_key and not _completed:
		return false
	
	route_key = new_route_key
	waypoints = new_waypoints
	is_looping = looping
	is_travel_route = travel
	_completed = false
	
	if waypoints.is_empty():
		waypoint_idx = 0
		return true
	
	# Start at nearest waypoint, then advance to next
	waypoint_idx = _find_nearest_idx(current_pos)
	if waypoints.size() > 1:
		waypoint_idx = (waypoint_idx + 1) % waypoints.size()
	
	return true


## Call when agent reaches current target. Returns the new target position,
## or Vector2.ZERO if route is complete.
func advance() -> Vector2:
	if waypoints.is_empty() or _completed:
		return Vector2.ZERO
	
	# At end of route?
	if waypoint_idx >= waypoints.size() - 1:
		if is_looping:
			waypoint_idx = 0
			return waypoints[0]
		else:
			_completed = true
			return Vector2.ZERO
	
	waypoint_idx += 1
	return waypoints[waypoint_idx]


## Check if position has reached current waypoint.
func has_reached_target(pos: Vector2) -> bool:
	if waypoints.is_empty() or _completed:
		return false
	var target := get_current_target()
	return pos.distance_to(target) <= _WAYPOINT_REACHED_EPS


func is_at_route_end() -> bool:
	if waypoints.is_empty():
		return true
	return waypoint_idx >= waypoints.size() - 1 and not is_looping


func _find_nearest_idx(pos: Vector2) -> int:
	if waypoints.is_empty():
		return 0
	var best_i := 0
	var best_d2 := INF
	for i in range(waypoints.size()):
		var d2 := pos.distance_squared_to(waypoints[i])
		if d2 < best_d2:
			best_d2 = d2
			best_i = i
	return best_i
