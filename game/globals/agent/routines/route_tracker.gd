class_name AgentRouteTracker
extends RefCounted

## AgentRouteTracker - manages route progress for a single agent.
##
## Tracks which route the agent is on, which waypoint they're targeting,
## and provides the next waypoint when the current one is reached.

const _WAYPOINT_REACHED_EPS := 2.0

var agent_id: StringName = &""
var route_key: StringName = &""
var waypoints: Array[WorldPoint] = []
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


func get_current_target() -> WorldPoint:
	if waypoints.is_empty() or _completed:
		return null
	return waypoints[clampi(waypoint_idx, 0, waypoints.size() - 1)]


func get_progress() -> float:
	if waypoints.is_empty():
		return 0.0
	return float(waypoint_idx) / float(max(1, waypoints.size()))


## Initialize or switch to a new route.
## Returns true if route was changed.
func set_route(
	new_route_key: StringName,
	new_waypoints: Array[WorldPoint],
	current_pos: Vector2,
	current_level_id: Enums.Levels,
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

	# Start at nearest waypoint in the CURRENT level, then advance to next
	waypoint_idx = _find_nearest_idx(current_pos, current_level_id)
	if waypoints.size() > 1:
		# Prefer the next waypoint that is still in the current level so online
		# agents don't start by targeting a point in another level.
		var tries := 0
		while tries < waypoints.size():
			waypoint_idx = (waypoint_idx + 1) % waypoints.size()
			if (
				waypoints[waypoint_idx] != null
				and waypoints[waypoint_idx].level_id == current_level_id
			):
				break
			tries += 1

	return true


## Call when agent reaches current target. Returns the new WorldPoint,
## or null if route is complete.
func advance() -> WorldPoint:
	if waypoints.is_empty() or _completed:
		return null

	# At end of route?
	if waypoint_idx >= waypoints.size() - 1:
		if is_looping:
			waypoint_idx = 0
			return waypoints[0]

		_completed = true
		return null
	waypoint_idx += 1
	return waypoints[waypoint_idx]


## Check if position has reached current waypoint.
func has_reached_target(pos: Vector2, level_id: Enums.Levels) -> bool:
	if waypoints.is_empty() or _completed:
		return false
	var target := get_current_target()
	if target == null:
		return false
	if target.level_id != level_id:
		return false
	return pos.distance_to(target.position) <= _WAYPOINT_REACHED_EPS


func is_at_route_end() -> bool:
	if waypoints.is_empty():
		return true
	return waypoint_idx >= waypoints.size() - 1 and not is_looping


func _find_nearest_idx(pos: Vector2, level_id: Enums.Levels) -> int:
	if waypoints.is_empty():
		return 0
	var best_i := 0
	var best_d2 := INF

	# Prefer waypoints in the same level
	for i in range(waypoints.size()):
		var wp := waypoints[i]
		if wp.level_id != level_id:
			continue
		var d2 := pos.distance_squared_to(wp.position)
		if d2 < best_d2:
			best_d2 = d2
			best_i = i

	# If no waypoints in the same level, just find the absolute nearest
	if best_d2 == INF:
		for i in range(waypoints.size()):
			var wp := waypoints[i]
			var d2 := pos.distance_squared_to(wp.position)
			if d2 < best_d2:
				best_d2 = d2
				best_i = i

	return best_i
