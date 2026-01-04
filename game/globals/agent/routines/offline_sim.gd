class_name AgentOfflineSim
extends RefCounted

## AgentOfflineSim - applies movement to offline (non-spawned) agents.
const _WAYPOINT_REACHED_EPS := 2.0


class Result:
	var changed: bool = false
	var committed_travel: bool = false


static func apply_order(
	rec: AgentRecord,
	order: AgentOrder,
	tracker: AgentRouteTracker,
	move_speed: float,
	registry: AgentRegistry
) -> Result:
	var result := Result.new()

	if rec == null or order == null:
		return result

	if order.action == AgentOrder.Action.IDLE:
		return result

	if tracker == null or not tracker.is_active():
		return result

	var step_dist := move_speed * _seconds_per_game_minute()
	if step_dist <= 0.0:
		return result

	var target := tracker.get_current_target()
	var to_target := target - rec.last_world_pos
	var dist := to_target.length()

	# Check if we've reached the waypoint
	if dist <= _WAYPOINT_REACHED_EPS:
		# At end of travel route? Commit travel.
		if tracker.is_travel_route and tracker.is_at_route_end():
			if order.is_traveling and order.travel_spawn_point != null:
				if registry != null:
					registry.commit_travel_by_id(rec.agent_id, order.travel_spawn_point)
				result.committed_travel = true
				result.changed = true
				tracker.reset()
				return result

		# Advance to next waypoint
		var next_target := tracker.advance()
		if next_target == Vector2.ZERO:
			return result

		target = next_target
		to_target = target - rec.last_world_pos
		dist = to_target.length()

	# Move toward target
	if dist > 0.0:
		var move_dist := minf(step_dist, dist)
		var new_pos := rec.last_world_pos + (to_target / dist) * move_dist
		if rec.last_world_pos != new_pos:
			rec.last_world_pos = new_pos
			result.changed = true

	return result


static func _seconds_per_game_minute() -> float:
	if TimeManager == null:
		return 0.0
	var mins := float(TimeManager.MINUTES_PER_DAY)
	if mins <= 0.0:
		mins = 1440.0
	var d := float(TimeManager.day_duration_seconds)
	if d <= 0.0:
		return 0.0
	return d / mins
