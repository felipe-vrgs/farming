@tool
extends EditorPlugin

const PLUGIN_NAME := "Scheduler"
const _WORLD_MAP_SCENE := "res://debug/world_map/world_map_editor.tscn"

signal edit_state_changed

const HANDLE_RADIUS_SPAWN := 10.0
const HANDLE_RADIUS_ROUTE := 8.0
const CLICK_THRESHOLD_ROUTE := 10.0

enum Kind { NONE, SPAWN_POINT, ROUTE }

var _view: Control = null

var current_obj: Object = null
var current_kind: int = Kind.NONE
var edit_mode: bool = false
var _edit_reentry_guard: bool = false
var _world_map_opening_frames_left: int = 0

# Spawn interaction state
var _spawn_dragging: bool = false
var _spawn_drag_start: Vector2 = Vector2.ZERO

# Route interaction state
var _route_dragged_point_index: int = -1
var _route_drag_start_wp: WorldPoint = null
var _route_hovered_point_index: int = -1
var _route_hovered_segment_index: int = -1


func _enter_tree() -> void:
	_view = preload("res://addons/schedule_editor_dock/editor_main.tscn").instantiate()
	if _view != null:
		if "plugin_reference" in _view:
			_view.set("plugin_reference", self)
		if _view.has_method("set_editor_interface"):
			_view.call("set_editor_interface", get_editor_interface())
		if _view.has_method("set_undo_redo"):
			_view.call("set_undo_redo", get_undo_redo())
		_view.hide()
		var main_screen := get_editor_interface().get_editor_main_screen()
		main_screen.add_child(_view)
		# Ensure the plugin root fills the editor main screen so TabContainer
		# stretches horizontally (anchors matter more than size_flags here).
		_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		_view.offset_left = 0
		_view.offset_top = 0
		_view.offset_right = 0
		_view.offset_bottom = 0
		_make_visible(false)
	set_process(true)


func _exit_tree() -> void:
	set_process(false)
	if _view != null:
		_view.queue_free()
	_view = null


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return PLUGIN_NAME


func _make_visible(visible: bool) -> void:
	if _view == null:
		return
	_view.visible = visible


func _handles(object: Object) -> bool:
	if object is NpcSchedule or object is NpcConfig:
		return true
	if object is SpawnPointData or object is RouteResource:
		return true

	# While actively editing in the 2D viewport, keep receiving canvas input.
	if edit_mode and object is Node and current_kind != Kind.NONE:
		return _is_world_map_open()

	return false


func _edit(object: Object) -> void:
	if object == null:
		return
	if _edit_reentry_guard:
		# Prevent infinite recursion when our UI calls EditorInterface.edit_resource(),
		# which triggers EditorPlugin._edit again.
		return
	_edit_reentry_guard = true

	if object is SpawnPointData or object is RouteResource:
		current_obj = object
		current_kind = Kind.SPAWN_POINT if object is SpawnPointData else Kind.ROUTE
		edit_state_changed.emit()
		update_overlays()

	_make_visible(true)
	if _view != null and _view.has_method("edit_resource"):
		_view.call("edit_resource", object)

	_edit_reentry_guard = false


func _process(_delta: float) -> void:
	if _world_map_opening_frames_left > 0:
		_world_map_opening_frames_left -= 1
	# If the user leaves the world map scene or 2D screen, auto-disable edit mode.
	if (
		edit_mode
		and _world_map_opening_frames_left <= 0
		and (not _is_world_map_open() or not _is_2d_screen_active())
	):
		_disable_edit_mode()


func is_editing(object: Object) -> bool:
	return edit_mode and object != null and object == current_obj


func set_current_object(object: Object) -> void:
	current_obj = object
	current_kind = Kind.NONE
	if object is SpawnPointData:
		current_kind = Kind.SPAWN_POINT
	elif object is RouteResource:
		current_kind = Kind.ROUTE
	edit_state_changed.emit()
	update_overlays()


func set_edit_mode_for(enabled: bool, object: Object) -> void:
	edit_mode = enabled
	current_obj = object
	current_kind = Kind.NONE
	if object is SpawnPointData:
		current_kind = Kind.SPAWN_POINT
	elif object is RouteResource:
		current_kind = Kind.ROUTE

	if enabled and current_obj != null:
		_request_open_world_map()
	else:
		_disable_edit_mode()

	edit_state_changed.emit()
	update_overlays()


func _disable_edit_mode() -> void:
	edit_mode = false
	_spawn_dragging = false
	_route_dragged_point_index = -1
	_route_hovered_point_index = -1
	_route_hovered_segment_index = -1
	edit_state_changed.emit()
	update_overlays()


func _is_world_map_open() -> bool:
	if get_editor_interface() == null:
		return false
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return false
	return String(root.scene_file_path) == _WORLD_MAP_SCENE


func _request_open_world_map() -> void:
	if get_editor_interface() == null:
		return
	if not FileAccess.file_exists(_WORLD_MAP_SCENE):
		return

	if not _is_world_map_open():
		# Prevent edit-mode from turning itself off while the editor switches scenes.
		_world_map_opening_frames_left = 90
		get_editor_interface().open_scene_from_path(_WORLD_MAP_SCENE)
		get_editor_interface().set_main_screen_editor("2D")
		call_deferred("_poll_world_map_ready", 60)
		return

	_try_rebuild_world_map()


## Public helper for the World Map tab (open + rebuild).
func open_world_map_editor() -> void:
	_request_open_world_map()


func _try_rebuild_world_map() -> void:
	var root: Node = null
	if get_editor_interface() != null:
		root = get_editor_interface().get_edited_scene_root()
	if root != null and root.has_method("_rebuild_world"):
		root.call("_rebuild_world")


func _poll_world_map_ready(frames_left: int) -> void:
	# Wait until the scene switch is complete, then rebuild the merged world.
	if _is_world_map_open():
		_world_map_opening_frames_left = 0
		_try_rebuild_world_map()
		return
	if frames_left <= 0:
		_world_map_opening_frames_left = 0
		return
	call_deferred("_poll_world_map_ready", frames_left - 1)


func _is_2d_screen_active() -> bool:
	var ei := get_editor_interface()
	if ei != null and ei.has_method("get_editor_viewport_2d"):
		var vp = ei.get_editor_viewport_2d()
		if vp != null and vp is Control:
			return (vp as Control).is_visible_in_tree()
	return true


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not edit_mode or current_obj == null or current_kind == Kind.NONE:
		return false
	if not _is_world_map_open():
		return false
	if current_kind == Kind.SPAWN_POINT:
		return _spawn_forward_input(event)
	if current_kind == Kind.ROUTE:
		return _route_forward_input(event)
	return false


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if current_obj == null or current_kind == Kind.NONE:
		return
	if not _is_2d_screen_active():
		return
	if not _is_world_map_open():
		return

	if current_kind == Kind.SPAWN_POINT:
		_draw_spawn_overlay(overlay)
	elif current_kind == Kind.ROUTE:
		_draw_route_overlay(overlay)


func _get_world_map_builder() -> Node:
	var root: Node = null
	if get_editor_interface() != null:
		root = get_editor_interface().get_edited_scene_root()
	if root == null:
		return null
	if root.has_method("_rebuild_world"):
		return root
	return null


func _get_viewport_canvas_transform() -> Transform2D:
	var out := Transform2D()
	var ei := get_editor_interface()
	if ei == null or not ei.has_method("get_editor_viewport_2d"):
		return out
	var vp := ei.get_editor_viewport_2d()
	if vp == null:
		return out

	# Godot versions differ here (SubViewport vs Control wrapper).
	# Try the common properties/methods without hard casting.
	if "global_canvas_transform" in vp:
		out = vp.global_canvas_transform
	elif vp.has_method("get_global_canvas_transform"):
		out = vp.call("get_global_canvas_transform")
	elif vp.has_method("get_canvas_transform"):
		out = vp.call("get_canvas_transform")
	elif "canvas_transform" in vp:
		out = vp.canvas_transform
	return out


func _get_mouse_position_world(screen_pos: Vector2) -> Vector2:
	var viewport_trans := _get_viewport_canvas_transform()
	return viewport_trans.affine_inverse() * screen_pos


func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x), round(pos.y))


func _get_world_point_from_mouse(mouse_pos: Vector2) -> WorldPoint:
	var wp := WorldPoint.new()

	var builder := _get_world_map_builder()
	if builder != null and builder.get("layout") != null:
		var layout: WorldEditorLayout = builder.get("layout") as WorldEditorLayout
		if layout == null:
			wp.position = _snap_to_grid(mouse_pos)
			return wp
		var best_level := Enums.Levels.NONE
		var best_local_pos := mouse_pos
		var min_dist := INF
		for level_id_var in layout.level_offsets.keys():
			var level_id := int(level_id_var)
			var offset: Vector2 = layout.get_level_offset(level_id)
			var dist: float = mouse_pos.distance_to(offset)
			if dist < min_dist:
				min_dist = dist
				best_level = level_id
				best_local_pos = mouse_pos - offset
		wp.level_id = best_level
		wp.position = _snap_to_grid(best_local_pos)
	else:
		if current_obj != null and "level_id" in current_obj:
			wp.level_id = current_obj.level_id
		wp.position = _snap_to_grid(mouse_pos)

	return wp


func _get_wp_global_pos(wp: WorldPoint) -> Vector2:
	if wp == null:
		return Vector2.ZERO
	var builder := _get_world_map_builder()
	if builder != null and builder.get("layout") != null:
		var layout: WorldEditorLayout = builder.get("layout") as WorldEditorLayout
		if layout == null:
			return wp.position
		return wp.position + layout.get_level_offset(wp.level_id)
	return wp.position


# --- Spawn ---
func _spawn_forward_input(event: InputEvent) -> bool:
	var sp := current_obj as SpawnPointData
	if sp == null:
		return false

	if event is InputEventMouseButton:
		return _spawn_handle_mouse_click(event as InputEventMouseButton, sp)
	if event is InputEventMouseMotion and _spawn_dragging:
		var mm := event as InputEventMouseMotion
		var mouse_pos := _get_mouse_position_world(mm.position)
		sp.position = _snap_to_grid(mouse_pos)
		update_overlays()
		return true
	return false


func _spawn_handle_mouse_click(mb: InputEventMouseButton, sp: SpawnPointData) -> bool:
	var mouse_pos := _get_mouse_position_world(mb.position)
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false

	var handled := false
	if mb.pressed:
		var handle_pos := _get_wp_global_pos(sp)
		var viewport_trans := _get_viewport_canvas_transform()
		var screen_handle := viewport_trans * handle_pos
		var screen_click := viewport_trans * mouse_pos
		if screen_handle.distance_to(screen_click) < HANDLE_RADIUS_SPAWN + 4.0:
			_spawn_dragging = true
			_spawn_drag_start = sp.position
			handled = true
		else:
			var new_wp := _get_world_point_from_mouse(mouse_pos)
			_spawn_set_wp(new_wp, sp)
			handled = true
	else:
		# release
		if _spawn_dragging:
			_spawn_end_drag(sp)
			_spawn_dragging = false
			handled = true

	return handled


func _spawn_set_wp(wp: WorldPoint, sp: SpawnPointData) -> void:
	var ur := get_undo_redo()
	ur.create_action("Set Spawn Point WorldPoint")
	ur.add_do_property(sp, "level_id", wp.level_id)
	ur.add_do_property(sp, "position", wp.position)
	ur.add_undo_property(sp, "level_id", sp.level_id)
	ur.add_undo_property(sp, "position", sp.position)
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


func _spawn_end_drag(sp: SpawnPointData) -> void:
	if _spawn_drag_start == sp.position:
		return
	var ur := get_undo_redo()
	ur.create_action("Move Spawn Point")
	var final_pos := sp.position
	ur.add_do_property(sp, "position", final_pos)
	ur.add_undo_property(sp, "position", _spawn_drag_start)
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


func _draw_spawn_overlay(overlay: Control) -> void:
	var sp := current_obj as SpawnPointData
	if sp == null:
		return
	var viewport_trans := _get_viewport_canvas_transform()
	var global_pos := _get_wp_global_pos(sp)
	var screen_pos := viewport_trans * global_pos

	var cross_size := 20.0
	var color := Color(0.8, 0.8, 0.8)
	if edit_mode:
		color = Color.LIME if not _spawn_dragging else Color.RED

	overlay.draw_line(
		screen_pos - Vector2(cross_size, 0),
		screen_pos + Vector2(cross_size, 0),
		color,
		2.0
	)
	overlay.draw_line(
		screen_pos - Vector2(0, cross_size),
		screen_pos + Vector2(0, cross_size),
		color,
		2.0
	)
	overlay.draw_circle(screen_pos, HANDLE_RADIUS_SPAWN, color)
	overlay.draw_circle(screen_pos, HANDLE_RADIUS_SPAWN * 0.7, Color.BLACK)

	var label := "Spawn Point"
	if sp.display_name != "":
		label = sp.display_name
	overlay.draw_string(
		ThemeDB.get_fallback_font(),
		screen_pos + Vector2(15, -15),
		"%s (L%s)\n(%d, %d)" % [label, sp.level_id, int(sp.position.x), int(sp.position.y)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color.WHITE
	)


# --- Route ---
func _route_forward_input(event: InputEvent) -> bool:
	var r := current_obj as RouteResource
	if r == null:
		return false

	if event is InputEventMouseButton:
		return _route_handle_mouse_click(event as InputEventMouseButton, r)

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var mouse_pos := _get_mouse_position_world(mm.position)

		var old_hover := _route_hovered_point_index
		var old_seg_hover := _route_hovered_segment_index

		_route_hovered_point_index = _route_get_point_at(mouse_pos, r)
		_route_hovered_segment_index = -1
		if _route_hovered_point_index == -1:
			_route_hovered_segment_index = _route_get_segment_at(mouse_pos, r)

		if _route_hovered_point_index != old_hover or _route_hovered_segment_index != old_seg_hover:
			update_overlays()

		if _route_dragged_point_index != -1:
			var wps := r.waypoints.duplicate()
			var wp := _get_world_point_from_mouse(mouse_pos)
			var dragged_wp := WorldPoint.new()
			dragged_wp.level_id = wp.level_id
			dragged_wp.position = wp.position
			wps[_route_dragged_point_index] = dragged_wp
			r.waypoints = wps
			update_overlays()
			return true

	return false


func _route_handle_mouse_click(mb: InputEventMouseButton, r: RouteResource) -> bool:
	var mouse_pos := _get_mouse_position_world(mb.position)

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var clicked_idx := _route_get_point_at(mouse_pos, r)
			if clicked_idx != -1:
				_route_dragged_point_index = clicked_idx
				var original := r.waypoints[clicked_idx]
				_route_drag_start_wp = WorldPoint.new()
				_route_drag_start_wp.level_id = original.level_id
				_route_drag_start_wp.position = original.position
				return true

			var seg_idx := _route_get_segment_at(mouse_pos, r)
			var wp2 := _get_world_point_from_mouse(mouse_pos)
			if seg_idx != -1:
				_route_insert_wp(seg_idx + 1, wp2, r)
				_route_dragged_point_index = seg_idx + 1
				_route_drag_start_wp = wp2
				return true

			_route_add_wp(wp2, r)
			_route_dragged_point_index = r.waypoints.size() - 1
			_route_drag_start_wp = wp2
			return true

		# release
		if _route_dragged_point_index != -1:
			_route_end_drag_wp(_route_dragged_point_index, r)
			_route_dragged_point_index = -1
			_route_drag_start_wp = null
			return true

	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var clicked_idx2 := _route_get_point_at(mouse_pos, r)
		if clicked_idx2 != -1:
			_route_delete_wp(clicked_idx2, r)
			return true

	return false


func _draw_route_overlay(overlay: Control) -> void:
	var r := current_obj as RouteResource
	if r == null:
		return
	var viewport_trans := _get_viewport_canvas_transform()

	if not edit_mode:
		_route_hovered_point_index = -1
		_route_hovered_segment_index = -1

	var wps := r.waypoints
	var count := wps.size()

	if count == 0:
		overlay.draw_string(
			ThemeDB.get_fallback_font(),
			Vector2(50, 50),
			"Click to add start point" if edit_mode else "No route points",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.YELLOW
		)
		return

	for i in range(count - 1):
		var p1 = viewport_trans * _get_wp_global_pos(wps[i])
		var p2 = viewport_trans * _get_wp_global_pos(wps[i + 1])
		var color := Color.CYAN
		if wps[i].level_id != wps[i + 1].level_id:
			color = Color.MAGENTA
		var width := 2.0
		if edit_mode and i == _route_hovered_segment_index:
			color = Color.YELLOW
			width = 4.0
		overlay.draw_line(p1, p2, color, width)

	for i2 in range(count):
		var p = viewport_trans * _get_wp_global_pos(wps[i2])
		var colorp := Color.WHITE
		var radius := HANDLE_RADIUS_ROUTE
		if edit_mode and i2 == _route_hovered_point_index:
			colorp = Color.GREEN
			radius = HANDLE_RADIUS_ROUTE * 1.2
		if edit_mode and i2 == _route_dragged_point_index:
			colorp = Color.RED
		overlay.draw_circle(p, radius, colorp)
		overlay.draw_circle(p, radius * 0.8, Color.BLACK)
		overlay.draw_string(
			ThemeDB.get_fallback_font(),
			p + Vector2(10, -10),
			"%d (L%d)" % [i2, wps[i2].level_id],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14
		)


func _route_get_point_at(world_pos: Vector2, r: RouteResource) -> int:
	var viewport_trans := _get_viewport_canvas_transform()
	var screen_click = viewport_trans * world_pos
	var wps = r.waypoints
	for i in range(wps.size()):
		var p_screen = viewport_trans * _get_wp_global_pos(wps[i])
		if p_screen.distance_to(screen_click) < HANDLE_RADIUS_ROUTE + 2.0:
			return i
	return -1


func _route_get_segment_at(world_pos: Vector2, r: RouteResource) -> int:
	var viewport_trans := _get_viewport_canvas_transform()
	var screen_click = viewport_trans * world_pos
	var wps = r.waypoints
	if wps.size() < 2:
		return -1
	for i in range(wps.size() - 1):
		var p1 = viewport_trans * _get_wp_global_pos(wps[i])
		var p2 = viewport_trans * _get_wp_global_pos(wps[i + 1])
		var closest = Geometry2D.get_closest_point_to_segment(screen_click, p1, p2)
		if closest.distance_to(screen_click) < CLICK_THRESHOLD_ROUTE:
			return i
	return -1


func _route_add_wp(wp: WorldPoint, r: RouteResource) -> void:
	var ur := get_undo_redo()
	ur.create_action("Add Route Waypoint")
	var new_wps := r.waypoints.duplicate()
	new_wps.append(wp)
	ur.add_do_property(r, "waypoints", new_wps)
	ur.add_undo_property(r, "waypoints", r.waypoints.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


func _route_insert_wp(idx: int, wp: WorldPoint, r: RouteResource) -> void:
	var ur := get_undo_redo()
	ur.create_action("Insert Route Waypoint")
	var new_wps := r.waypoints.duplicate()
	new_wps.insert(idx, wp)
	ur.add_do_property(r, "waypoints", new_wps)
	ur.add_undo_property(r, "waypoints", r.waypoints.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


func _route_end_drag_wp(idx: int, r: RouteResource) -> void:
	var current := r.waypoints[idx]
	if (
		_route_drag_start_wp.level_id == current.level_id
		and _route_drag_start_wp.position == current.position
	):
		return
	var ur := get_undo_redo()
	ur.create_action("Move Route Waypoint")

	var final_wps := []
	for wp in r.waypoints:
		var copy := WorldPoint.new()
		copy.level_id = wp.level_id
		copy.position = wp.position
		final_wps.append(copy)

	var initial_wps := []
	for i in range(r.waypoints.size()):
		var wp2 := r.waypoints[i]
		var copy2 := WorldPoint.new()
		if i == idx:
			copy2.level_id = _route_drag_start_wp.level_id
			copy2.position = _route_drag_start_wp.position
		else:
			copy2.level_id = wp2.level_id
			copy2.position = wp2.position
		initial_wps.append(copy2)

	ur.add_do_property(r, "waypoints", final_wps)
	ur.add_undo_property(r, "waypoints", initial_wps)
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


func _route_delete_wp(idx: int, r: RouteResource) -> void:
	var ur := get_undo_redo()
	ur.create_action("Delete Route Waypoint")
	var new_wps := r.waypoints.duplicate()
	new_wps.remove_at(idx)
	ur.add_do_property(r, "waypoints", new_wps)
	ur.add_undo_property(r, "waypoints", r.waypoints.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()
