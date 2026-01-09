class_name AgentDebugModule
extends DebugGridModule

var _show_hud: bool = false


func _is_grid_enabled() -> bool:
	if _debug_grid == null:
		return false
	if _debug_grid.has_method("is_grid_enabled"):
		return bool(_debug_grid.call("is_grid_enabled"))
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5 or event.keycode == KEY_F6:
			_show_hud = not _show_hud
			_toggle_npc_debug_avoidance(_show_hud)
			_debug_grid.queue_redraw()


func _toggle_npc_debug_avoidance(enabled: bool) -> void:
	if _debug_grid == null:
		return
	var npc_nodes = _debug_grid.get_tree().get_nodes_in_group(Groups.NPC_GROUP)
	for node in npc_nodes:
		if node is NPC:
			node.debug_avoidance = enabled
			if not enabled:
				# Force clear lines immediately if disabled
				if node.has_method("_clear_debug"):  # private method, technically, but accessible
					node.call("_clear_debug")


func _draw(_tile_size: Vector2) -> void:
	# Agent markers are shown if either the grid is enabled (F3) or agent HUD is enabled (F5).
	if not _is_grid_enabled() and not _show_hud:
		return

	# 1. Active Agents (Groups.AGENT_COMPONENTS)
	var active_ids = {}
	var agent_nodes = _debug_grid.get_tree().get_nodes_in_group(Groups.AGENT_COMPONENTS)

	for ac in agent_nodes:
		if not (ac is AgentComponent):
			continue
		var host = ac.get_parent()
		if host.name == "Components":
			host = host.get_parent()
		if not (host is Node2D):
			continue

		var pos = _debug_grid.to_local(host.global_position)
		var color = Color.CYAN if ac.kind == Enums.AgentKind.PLAYER else Color.RED

		_debug_grid.draw_circle(pos, 5, color)
		_debug_grid.draw_string(
			_font,
			pos + Vector2(-10, -10),
			str(ac.agent_id),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			8,
			color
		)
		active_ids[ac.agent_id] = true

	# 2. Offline/Ghost Agents (AgentRegistry)
	if AgentBrain.registry:
		var level_id = _get_active_level_id()
		var agents = AgentBrain.registry.debug_get_agents()
		for id in agents:
			if active_ids.has(id):
				continue
			var rec = agents[id]
			if int(rec.current_level_id) == int(level_id):
				# FIX: Applying Y-offset for offline agents if they seem to be using tile-center routes
				# but NPC pivot is at feet.
				var pos = rec.last_world_pos

				# We only apply the offset if the NPC is simulated on a route.
				# If it was just captured from a live NPC, last_world_pos is already at feet.
				# However, if it's offline, it's likely being driven by simulation.
				var draw_pos = _debug_grid.to_local(pos)

				_debug_grid.draw_circle(draw_pos, 4, Color.GRAY)
				_debug_grid.draw_string(
					_font,
					draw_pos + Vector2(-10, -10),
					"%s(off)" % id,
					HORIZONTAL_ALIGNMENT_CENTER,
					-1,
					8,
					Color.GRAY
				)


func _update_hud(lines: Array[String]) -> void:
	# HUD is shown if enabled (F5), independent of grid overlay.
	if not _show_hud:
		return

	if AgentBrain.registry:
		lines.append("--- Agent Registry ---")
		var agents = AgentBrain.registry.debug_get_agents()

		var ids = agents.keys()
		ids.sort()

		var active_level_id = _get_active_level_id()
		for id in ids:
			var rec = agents[id]
			var lname = _get_enum_string(Enums.Levels, int(rec.current_level_id))
			var pos_str = "(%d,%d)" % [int(rec.last_world_pos.x), int(rec.last_world_pos.y)]

			var prefix = "[*] " if int(rec.current_level_id) == active_level_id else "    "
			lines.append("%s%s @ %s %s" % [prefix, id, lname, pos_str])

			# Schedule debug (best-effort)
			var cfg: NpcConfig = null
			if AgentBrain.spawner != null:
				cfg = AgentBrain.spawner.get_npc_config(StringName(id))
			if cfg == null or cfg.schedule == null or TimeManager == null:
				continue

			var minute := int(TimeManager.get_minute_of_day())
			var resolved := ScheduleResolver.resolve(cfg.schedule, minute)
			if resolved == null or resolved.step == null:
				lines.append("      sched: <none>")
				continue

			var step := resolved.step
			var kind_str := "HOLD"
			match step.kind:
				NpcScheduleStep.Kind.ROUTE:
					kind_str = "ROUTE"
				NpcScheduleStep.Kind.IDLE_AROUND:
					kind_str = "IDLE_AROUND"
				_:
					kind_str = "HOLD"
			var start := int(step.start_minute_of_day)
			var end_val := int(step.get_end_minute_of_day())
			var window := "%s-%s" % [_fmt_hm(start), _fmt_hm(end_val)]

			var flags: Array[String] = []
			var order := AgentBrain.get_order(StringName(id))
			var tracker := AgentBrain.get_tracker(StringName(id))
			var override_info := AgentBrain.debug_get_schedule_override_info(StringName(id))
			if not override_info.is_empty():
				flags.append("OVERRIDE")

			# LENIENT: schedule says HOLD but we're still moving on a non-loop route
			if (
				step.kind != NpcScheduleStep.Kind.ROUTE
				and tracker != null
				and tracker.is_active()
				and not tracker.is_looping
			):
				flags.append("LENIENT")

			# CHAINED: schedule ROUTE doesn't match the currently executed route key
			if (
				step.kind == NpcScheduleStep.Kind.ROUTE
				and order != null
				and order.is_on_route
				and step.route_res != null
			):
				# Route keys now include suffixes (e.g. ":<day>:<step_idx>").
				# Treat it as chained only if it doesn't match the expected prefix.
				var expected_prefix := "route:" + String(step.route_res.resource_path)
				if not String(order.route_key).begins_with(expected_prefix):
					flags.append("CHAINED")

			# HOLD_LATE: schedule is HOLD but we're still moving and close to end
			if step.kind != NpcScheduleStep.Kind.ROUTE and minute >= end_val - 5:
				if flags.has("LENIENT"):
					flags.append("HOLD_LATE")

			var flags_str: String = (" [" + ", ".join(flags) + "]") if not flags.is_empty() else ""
			var progress_str: String = ""
			var override_str: String = ""
			if not override_info.is_empty():
				var exp_min := int(override_info.get("expire_minute", -1))
				if exp_min >= 0:
					override_str = " < %s" % _fmt_hm(exp_min)
			if order != null and order.is_on_route:
				# AgentOrder stores route_progress as 0..1, approximate to "i/N"
				# for quick debugging.
				var n: int = 1
				if tracker != null:
					n = maxi(1, tracker.waypoints.size())
				var i: int = int(floor(order.route_progress * float(n)))
				i = clampi(i, 0, max(0, n - 1))
				progress_str = " (%d/%d)" % [i + 1, n]
			elif order != null and order.action == AgentOrder.Action.MOVE_TO:
				# Non-route movement (e.g. IDLE_AROUND) - show target distance.
				var d = rec.last_world_pos.distance_to(order.target_position)
				progress_str = " (to %.0fpx)" % d

			lines.append(
				(
					"      sched: %s %s%s%s%s"
					% [window, kind_str, flags_str, override_str, progress_str]
				)
			)

		if ids.is_empty():
			lines.append("(no agents recorded)")


func _fmt_hm(minute_of_day: int) -> String:
	var m := minute_of_day % (24 * 60)
	if m < 0:
		m += 24 * 60
	var hh := int(m / 60.0)
	var mm := int(m % 60)
	return "%02d:%02d" % [hh, mm]


func is_enabled() -> bool:
	# Module is active if the grid is on OR if we are showing the agent HUD.
	return _is_grid_enabled() or _show_hud


func is_hud_enabled() -> bool:
	return _show_hud


func _get_active_level_id() -> int:
	if _debug_grid == null:
		return -1
	var scene := _debug_grid.get_tree().current_scene
	if scene is LevelRoot:
		return int((scene as LevelRoot).level_id)
	if scene != null:
		var lr = scene.get_node_or_null(NodePath("LevelRoot"))
		if lr is LevelRoot:
			return int((lr as LevelRoot).level_id)
	return -1
