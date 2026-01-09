class_name AgentOfflineSim
extends RefCounted

## AgentOfflineSim - applies movement to offline (non-spawned) agents.
const _WAYPOINT_REACHED_EPS := 2.0


class Result:
	var changed: bool = false
	var committed_travel: bool = false
	var reached_target: bool = false


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

	var step_dist := move_speed * _seconds_per_game_minute()
	if step_dist <= 0.0:
		return result

	# Non-route MOVE_TO (e.g. schedule IDLE_AROUND): move directly toward target_position.
	if tracker == null or not tracker.is_active():
		var target_pos2 := order.target_position
		var to_target2 := target_pos2 - rec.last_world_pos
		var dist2 := to_target2.length()
		if dist2 <= _WAYPOINT_REACHED_EPS:
			result.reached_target = true
			return result
		if dist2 > 0.0:
			var move_dist2 := minf(step_dist, dist2)
			var new_pos2 := rec.last_world_pos + (to_target2 / dist2) * move_dist2
			if move_dist2 >= dist2:
				new_pos2 = target_pos2
				result.reached_target = true
			if rec.last_world_pos != new_pos2:
				rec.last_world_pos = new_pos2
				result.changed = true
		return result

	var target_wp := tracker.get_current_target()
	if target_wp == null:
		return result

	# Check if waypoint is in another level
	if target_wp.level_id != rec.current_level_id:
		# Teleport immediately
		if registry != null:
			var sp := SpawnPointData.new()
			sp.level_id = target_wp.level_id
			sp.position = target_wp.position
			registry.commit_travel_by_id(rec.agent_id, sp)
		result.committed_travel = true
		result.changed = true
		# Continue to next waypoint in next tick (or advance now?)
		# For offline sim, we can just advance now.
		target_wp = tracker.advance()
		if target_wp == null:
			return result

	var target_pos := target_wp.position
	var to_target := target_pos - rec.last_world_pos
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
		var next_wp := tracker.advance()
		if next_wp == null:
			return result

		target_pos = next_wp.position
		to_target = target_pos - rec.last_world_pos
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
