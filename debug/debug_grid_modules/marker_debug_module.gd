class_name MarkerDebugModule
extends DebugGridModule

var _show_markers: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F4:
			_show_markers = not _show_markers
			_debug_grid.queue_redraw()

func _draw(_tile_size: Vector2) -> void:
	if not _show_markers:
		return

	var root = _find_level_root()
	if not root:
		root = _debug_grid.get_tree().current_scene
	if not root:
		return

	# Spawns
	var spawns = _debug_grid.get_tree().get_nodes_in_group(Groups.SPAWN_MARKERS)
	for node in spawns:
		if not (node is Node2D): continue
		if not node.is_inside_tree(): continue

		var pos = _debug_grid.to_local(node.global_position)
		_debug_grid.draw_circle(pos, 3, Color.YELLOW)
		var sid = int(node.get("spawn_id"))
		var sname = _get_enum_string(Enums.SpawnId, sid)
		_debug_grid.draw_string(
			_font,
			pos + Vector2(5, 5),
			"S:%s" % sname,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			8,
			Color.YELLOW
		)

	# Travel Zones
	var travel_zones = _find_travel_zones_recursive(root)
	for tz in travel_zones:
		if not (tz is Node2D): continue
		var pos = _debug_grid.to_local(tz.global_position)
		_debug_grid.draw_circle(pos, 3, Color.MAGENTA)
		var tlid = int(tz.get("target_level_id") if "target_level_id" in tz else -1)
		var tlname = _get_enum_string(Enums.Levels, tlid)
		_debug_grid.draw_string(
			_font,
			pos + Vector2(5, 5),
			"TO:%s" % tlname,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			8,
			Color.MAGENTA
		)

func _find_level_root() -> Node:
	var scene = _debug_grid.get_tree().current_scene
	if scene is LevelRoot:
		return scene
	var lr = scene.get_node_or_null("LevelRoot")
	if lr is LevelRoot:
		return lr
	return null

func _find_travel_zones_recursive(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	if node is TravelZone:
		out.append(node)

	for c in node.get_children():
		out.append_array(_find_travel_zones_recursive(c))
	return out

func is_enabled() -> bool:
	return _show_markers
