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

	# Travel Zones
	var travel_zones = _find_travel_zones_recursive(root)
	for tz in travel_zones:
		if not (tz is Node2D):
			continue
		var pos = _debug_grid.to_local(tz.global_position)
		_debug_grid.draw_circle(pos, 3, Color.MAGENTA)

		var sp: SpawnPointData = tz.get("target_spawn_point") as SpawnPointData
		var label := "???"
		if sp != null:
			var level_name := _get_enum_string(Enums.Levels, int(sp.level_id))
			label = "TO:%s" % level_name
		_debug_grid.draw_string(
			_font, pos + Vector2(5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.MAGENTA
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
