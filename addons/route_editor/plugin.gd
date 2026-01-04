@tool
extends EditorPlugin

signal edit_state_changed

const HANDLE_RADIUS = 8.0
const CLICK_THRESHOLD = 10.0
const RouteInspectorPlugin = preload("res://addons/route_editor/route_inspector.gd")

var inspector_plugin
var current_route: RouteResource
var edit_mode: bool = false
var dragged_point_index: int = -1
var drag_start_pos: Vector2
var hovered_point_index: int = -1
var hovered_segment_index: int = -1

func _enter_tree() -> void:
	inspector_plugin = RouteInspectorPlugin.new()
	inspector_plugin.init(self)
	add_inspector_plugin(inspector_plugin)

func _exit_tree() -> void:
	remove_inspector_plugin(inspector_plugin)
	if inspector_plugin:
		inspector_plugin = null

func _handles(object: Object) -> bool:
	if object is RouteResource:
		return true

	# If we are in edit mode, we want to capture input even if the user clicks on Nodes
	# in the scene, to prevent deselection of the RouteResource (if possible)
	# or just to allow drawing.
	if edit_mode and object is Node:
		# Safety check: only handle if the current route belongs to the edited scene
		# or if no level_id is set.
		if current_route:
			var scene_root = EditorInterface.get_edited_scene_root()
			if scene_root:
				var scene_path = scene_root.scene_file_path
				var route_level_path = _get_level_path(current_route.level_id)
				if route_level_path == "" or route_level_path == scene_path:
					return true
		else:
			# No route to edit, so we shouldn't be in edit_mode anyway,
			# but we'll return false to be safe.
			return false

	return false

func _get_level_path(level_id: int) -> String:
	match level_id:
		Enums.Levels.ISLAND: return "res://game/levels/island.tscn"
		Enums.Levels.FRIEREN_HOUSE: return "res://game/levels/frieren_house.tscn"
	return ""

func _edit(object: Object) -> void:
	if object is RouteResource:
		current_route = object
		edit_state_changed.emit()
		update_overlays()
	elif object == null:
		# If everything is deselected, we keep the current_route to allow
		# continuing editing, but we check if we should still be active.
		update_overlays()
	# If object is Node, we ignore it to preserve current_route while editing.

func set_edit_mode(enabled: bool, route: RouteResource) -> void:
	edit_mode = enabled
	current_route = route

	if enabled and current_route:
		_open_level_for_route(current_route)

	edit_state_changed.emit()
	update_overlays()

func _open_level_for_route(route: RouteResource) -> void:
	if route.level_id == Enums.Levels.NONE: return

	var level_name = ""
	# Hardcoded map based on Enums.Levels
	match route.level_id:
		Enums.Levels.ISLAND: level_name = "island"
		Enums.Levels.FRIEREN_HOUSE: level_name = "frieren_house"

	if level_name != "":
		var path = "res://game/levels/%s.tscn" % level_name
		if FileAccess.file_exists(path):
			# Only open if not already the edited scene
			var current = EditorInterface.get_edited_scene_root()
			if current and current.scene_file_path == path:
				return

			EditorInterface.open_scene_from_path(path)
			print("Switched to scene: ", path)

			# HACK: Restoring focus to the route resource after scene switch.
			# Godot's scene switch automatically selects the root node.
			# We defer the re-selection to the next frame.
			call_deferred("_restore_route_selection", route)

func _restore_route_selection(route: RouteResource) -> void:
	# Reselect the route resource so the inspector panel comes back.
	# We have to clear the node selection first.
	var selection = EditorInterface.get_selection()
	selection.clear()

	# To "select" a resource in the inspector, we use edit_resource()
	EditorInterface.edit_resource(route)

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not edit_mode or not current_route:
		return false

	if event is InputEventMouseButton:
		return _handle_mouse_click(event as InputEventMouseButton)

	if event is InputEventMouseMotion:
		var mouse_pos = _get_mouse_position_world(event.position)

		# Update hover state
		var old_hover = hovered_point_index
		var old_seg_hover = hovered_segment_index

		hovered_point_index = _get_point_at(mouse_pos)
		hovered_segment_index = -1
		if hovered_point_index == -1:
			hovered_segment_index = _get_segment_at(mouse_pos)

		if hovered_point_index != old_hover or hovered_segment_index != old_seg_hover:
			update_overlays()

		# Handle dragging
		if dragged_point_index != -1:
			var pts = current_route.points_world
			pts[dragged_point_index] = mouse_pos
			current_route.points_world = pts
			update_overlays()
			return true

	return false

func _handle_mouse_click(mb: InputEventMouseButton) -> bool:
	var mouse_pos = _get_mouse_position_world(mb.position)

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# Check for click on existing point
			var clicked_idx = _get_point_at(mouse_pos)
			if clicked_idx != -1:
				dragged_point_index = clicked_idx
				drag_start_pos = current_route.points_world[clicked_idx]
				return true

			# Check for click on segment (insert)
			var seg_idx = _get_segment_at(mouse_pos)
			if seg_idx != -1:
				_insert_point(seg_idx + 1, mouse_pos)
				dragged_point_index = seg_idx + 1
				drag_start_pos = mouse_pos
				return true

			# Add new point
			_add_point(mouse_pos)
			dragged_point_index = current_route.points_world.size() - 1
			drag_start_pos = mouse_pos
			return true
		# Mouse release
		if dragged_point_index != -1:
			_end_drag_point(dragged_point_index)
			dragged_point_index = -1
			return true

	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var clicked_idx = _get_point_at(mouse_pos)
		if clicked_idx != -1:
			_delete_point(clicked_idx)
			return true

	return false

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not edit_mode or not current_route:
		return

	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform

	var points = current_route.points_world
	var count = points.size()

	# Draw "Add Point Hint" if empty
	if count == 0:
		var label_pos = Vector2(50, 50)
		overlay.draw_string(
			ThemeDB.get_fallback_font(),
			label_pos, "Click to add start point",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.YELLOW
		)
		return

	# Draw segments
	for i in range(count - 1):
		var p1 = viewport_trans * points[i]
		var p2 = viewport_trans * points[i+1]
		var color = Color.CYAN
		var width = 2.0

		if i == hovered_segment_index:
			color = Color.YELLOW
			width = 4.0

		overlay.draw_line(p1, p2, color, width)

	# Draw loop closure if needed
	if current_route.loop_default and count > 2:
		var p1 = viewport_trans * points[count-1]
		var p2 = viewport_trans * points[0]
		overlay.draw_line(p1, p2, Color.CYAN.darkened(0.5), 2.0)

	# Draw points
	for i in range(count):
		var p = viewport_trans * points[i]
		var color = Color.WHITE
		var radius = HANDLE_RADIUS

		if i == hovered_point_index:
			color = Color.GREEN
			radius = HANDLE_RADIUS * 1.2

		if i == dragged_point_index:
			color = Color.RED

		overlay.draw_circle(p, radius, color)
		overlay.draw_circle(p, radius * 0.8, Color.BLACK) # Hollow effect

		overlay.draw_string(
			ThemeDB.get_fallback_font(),
			p + Vector2(10, -10),
			str(i),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14
		)

func _get_mouse_position_world(screen_pos: Vector2) -> Vector2:
	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	return viewport_trans.affine_inverse() * screen_pos

func _get_point_at(world_pos: Vector2) -> int:
	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var screen_click = viewport_trans * world_pos

	var points = current_route.points_world
	for i in range(points.size()):
		var p_screen = viewport_trans * points[i]
		if p_screen.distance_to(screen_click) < HANDLE_RADIUS + 2.0:
			return i
	return -1

func _get_segment_at(world_pos: Vector2) -> int:
	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var screen_click = viewport_trans * world_pos
	var threshold = CLICK_THRESHOLD

	var points = current_route.points_world
	if points.size() < 2:
		return -1

	for i in range(points.size() - 1):
		var p1 = viewport_trans * points[i]
		var p2 = viewport_trans * points[i+1]

		var closest = Geometry2D.get_closest_point_to_segment(screen_click, p1, p2)
		if closest.distance_to(screen_click) < threshold:
			return i
	return -1

func _add_point(pos: Vector2) -> void:
	var ur = get_undo_redo()
	ur.create_action("Add Route Point")

	var new_points = current_route.points_world.duplicate()
	new_points.append(pos)

	ur.add_do_property(current_route, "points_world", new_points)
	ur.add_undo_property(current_route, "points_world", current_route.points_world.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()

func _insert_point(idx: int, pos: Vector2) -> void:
	var ur = get_undo_redo()
	ur.create_action("Insert Route Point")

	var new_points = current_route.points_world.duplicate()
	new_points.insert(idx, pos)

	ur.add_do_property(current_route, "points_world", new_points)
	ur.add_undo_property(current_route, "points_world", current_route.points_world.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()

func _end_drag_point(idx: int) -> void:
	if drag_start_pos == current_route.points_world[idx]:
		return

	var ur = get_undo_redo()
	ur.create_action("Move Route Point")

	# The point is already at the new position in the current object
	# We need to save this new state as the DO state, and the old pos as UNDO state
	var final_points = current_route.points_world.duplicate()
	var initial_points = current_route.points_world.duplicate()
	initial_points[idx] = drag_start_pos

	ur.add_do_property(current_route, "points_world", final_points)
	ur.add_undo_property(current_route, "points_world", initial_points)
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()

func _delete_point(idx: int) -> void:
	var ur = get_undo_redo()
	ur.create_action("Delete Route Point")

	var new_points = current_route.points_world.duplicate()
	new_points.remove_at(idx)

	ur.add_do_property(current_route, "points_world", new_points)
	ur.add_undo_property(current_route, "points_world", current_route.points_world.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()
