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
		if event.keycode == KEY_F5:
			_show_hud = not _show_hud
			_debug_grid.queue_redraw()

func _draw(_tile_size: Vector2) -> void:
	# Agent markers are part of the default grid overlay (F3).
	if not _is_grid_enabled():
		return

	# 1. Active Agents (Groups.AGENT_COMPONENTS)
	var active_ids = {}
	var agent_nodes = _debug_grid.get_tree().get_nodes_in_group(Groups.AGENT_COMPONENTS)

	for ac in agent_nodes:
		if not (ac is AgentComponent): continue
		var host = ac.get_parent()
		if host.name == "Components":
			host = host.get_parent()
		if not (host is Node2D): continue

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
			if active_ids.has(id): continue
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
	# HUD is also nested under the default grid overlay (F3).
	if not _show_hud or not _is_grid_enabled():
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

		if ids.is_empty():
			lines.append("(no agents recorded)")

func is_enabled() -> bool:
	# No standalone toggle: this module is enabled whenever the grid is enabled.
	return _is_grid_enabled()

func is_hud_enabled() -> bool:
	return _show_hud and _is_grid_enabled()

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