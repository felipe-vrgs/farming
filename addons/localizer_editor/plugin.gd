@tool
extends EditorPlugin

signal edit_state_changed

const HANDLE_RADIUS_SPAWN := 10.0
const HANDLE_RADIUS_ROUTE := 8.0
const CLICK_THRESHOLD_ROUTE := 10.0

const _SCENE_SWITCH_POLL_FRAMES := 30
const _SCENE_SWITCH_MAX_RETRIES := 2

const LocalizerInspectorPlugin = preload("res://addons/localizer_editor/localizer_inspector.gd")

enum Kind { NONE, SPAWN_POINT, ROUTE }

var inspector_plugin

var current_obj: Object = null
var current_kind: int = Kind.NONE
var edit_mode: bool = false

# Spawn interaction state
var _spawn_dragging: bool = false
var _spawn_drag_start: Vector2 = Vector2.ZERO

# Route interaction state
var _route_dragged_point_index: int = -1
var _route_drag_start_wp: WorldPoint = null # Store original wp for undo
var _route_hovered_point_index: int = -1
var _route_hovered_segment_index: int = -1

# ... (keep existing scene switching logic) ...

func _is_world_map_context() -> bool:
	var root = EditorInterface.get_edited_scene_root()
	if root == null: return false
	return root.has_method("_rebuild_world") or root.name == "WorldMapEditor"

func _get_world_map_builder() -> Node:
	var root = EditorInterface.get_edited_scene_root()
	if root == null: return null
	if root.has_method("_rebuild_world"): return root
	return null

## Convert editor world position to a WorldPoint (level + local pos).
func _get_world_point_from_mouse(mouse_pos: Vector2) -> WorldPoint:
	var wp = WorldPoint.new()

	var builder = _get_world_map_builder()
	if builder != null and builder.get("layout") != null:
		var layout = builder.get("layout")
		# Find which level this point belongs to
		var best_level = Enums.Levels.NONE
		var best_local_pos = mouse_pos
		var min_dist = INF

		# Simple heuristic: find level whose offset is closest to mouse_pos
		# In a real tool, we might check bounds, but for now this works if levels don't overlap.
		for level_id_var in layout.level_offsets.keys():
			var level_id = int(level_id_var)
			var offset = layout.get_level_offset(level_id)
			var dist = mouse_pos.distance_to(offset)
			if dist < min_dist:
				min_dist = dist
				best_level = level_id
				best_local_pos = mouse_pos - offset
		wp.level_id = best_level
		wp.position = _snap_to_grid(best_local_pos)
	else:
		# Fallback to current object's level
		if current_obj != null and "level_id" in current_obj:
			wp.level_id = current_obj.level_id
		wp.position = _snap_to_grid(mouse_pos)
	return wp

## Get the global editor position for a WorldPoint.
func _get_wp_global_pos(wp: WorldPoint) -> Vector2:
	if wp == null: return Vector2.ZERO
	var builder = _get_world_map_builder()
	if builder != null and builder.get("layout") != null:
		var layout = builder.get("layout")
		return wp.position + layout.get_level_offset(wp.level_id)
	return wp.position

# Scene switching guard: avoid re-entrancy/crashes when selecting resources from other scenes.
var _pending_scene_path: String = ""
var _pending_selection_restore: Object = null
var _scene_switch_deferred: bool = false
var _scene_switch_in_flight: bool = false
var _scene_switch_target: String = ""
var _scene_switch_frames_left: int = 0
var _scene_switch_retries: int = 0


func _enter_tree() -> void:
	inspector_plugin = LocalizerInspectorPlugin.new()
	inspector_plugin.init(self)
	add_inspector_plugin(inspector_plugin)
	set_process(true)


func _exit_tree() -> void:
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
	set_process(false)


func _process(_delta: float) -> void:
	# If the user leaves the 2D editor screen, auto-disable edit mode and stop interaction.
	if edit_mode and not _is_2d_screen_active():
		_disable_edit_mode()


func _is_2d_screen_active() -> bool:
	# Robust: base on 2D viewport visibility.
	if EditorInterface != null and EditorInterface.has_method("get_editor_viewport_2d"):
		var vp = EditorInterface.get_editor_viewport_2d()
		if vp != null and vp is Control:
			return (vp as Control).is_visible_in_tree()
	return true


func _disable_edit_mode() -> void:
	edit_mode = false
	_spawn_dragging = false
	_route_dragged_point_index = -1
	_route_hovered_point_index = -1
	_route_hovered_segment_index = -1
	edit_state_changed.emit()
	update_overlays()


func _handles(object: Object) -> bool:
	if object is SpawnPointData or object is RouteResource:
		return true

	# In edit mode, capture viewport clicks to avoid deselection + to allow switching scenes.
	if edit_mode and object is Node and current_kind != Kind.NONE:
		var path := _get_target_scene_path()
		return path != "" and FileAccess.file_exists(path)

	return false


func _edit(object: Object) -> void:
	if object is SpawnPointData or object is RouteResource:
		current_obj = object
		current_kind = Kind.SPAWN_POINT if object is SpawnPointData else Kind.ROUTE

		# Clear node selection to avoid TileMap/GridMap tools capturing input.
		var selection = EditorInterface.get_selection()
		if selection != null:
			selection.clear()

		_request_open_level_for_current()
		edit_state_changed.emit()
		update_overlays()
		return

	if object == null:
		# Keep last object for preview overlay.
		update_overlays()


func is_editing(object: Object) -> bool:
	return edit_mode and object != null and object == current_obj


func set_edit_mode_for(enabled: bool, object: Object) -> void:
	edit_mode = enabled
	current_obj = object
	current_kind = Kind.NONE
	if object is SpawnPointData:
		current_kind = Kind.SPAWN_POINT
	elif object is RouteResource:
		current_kind = Kind.ROUTE

	if enabled and current_obj != null:
		# Clear node selection to avoid TileMap/GridMap tools capturing input.
		var selection = EditorInterface.get_selection()
		if selection != null:
			selection.clear()
		_request_open_level_for_current()
	else:
		_disable_edit_mode()

	edit_state_changed.emit()
	update_overlays()


func _get_level_path(level_id: int) -> String:
	match level_id:
		Enums.Levels.ISLAND:
			return "res://game/levels/island.tscn"
		Enums.Levels.FRIEREN_HOUSE:
			return "res://game/levels/frieren_house.tscn"
		Enums.Levels.PLAYER_HOUSE:
			return "res://game/levels/player_house.tscn"
	return ""


func _get_target_scene_path() -> String:
	return "res://debug/world_map/world_map_editor.tscn"


func _request_open_level_for_current() -> void:
	var path := _get_target_scene_path()
	if path == "" or not FileAccess.file_exists(path):
		return

	# If already open, just rebuild.
	var current = EditorInterface.get_edited_scene_root()
	var current_path := String(current.scene_file_path) if current else ""
	if current_path == path:
		if current.has_method("_rebuild_world"):
			current.call("_rebuild_world")
		return

	_pending_scene_path = path
	_pending_selection_restore = current_obj

	# If a switch is already happening, just queue the latest desired scene.
	if _scene_switch_in_flight:
		return
	_defer_scene_switch()


func _defer_scene_switch() -> void:
	if _scene_switch_deferred:
		return
	_scene_switch_deferred = true
	call_deferred("_perform_scene_switch_if_needed")


func _perform_scene_switch_if_needed() -> void:
	_scene_switch_deferred = false
	if _scene_switch_in_flight:
		return
	if _pending_scene_path == "":
		return

	var desired := _pending_scene_path
	var obj := _pending_selection_restore

	var current = EditorInterface.get_edited_scene_root()
	var current_path := String(current.scene_file_path) if current else ""
	if current_path == desired:
		_pending_scene_path = ""
		_pending_selection_restore = null
		_scene_switch_retries = 0
		return

	_scene_switch_in_flight = true
	_scene_switch_target = desired
	_scene_switch_frames_left = _SCENE_SWITCH_POLL_FRAMES
	EditorInterface.open_scene_from_path(desired)
	call_deferred("_poll_scene_switch")

	# Restore inspector focus after switch (best-effort).
	if obj != null:
		call_deferred("_restore_resource_selection_when_ready", obj, desired, 20)


func _poll_scene_switch() -> void:
	if not _scene_switch_in_flight:
		return
	var desired := _scene_switch_target
	if desired == "":
		_scene_switch_in_flight = false
		return

	var current = EditorInterface.get_edited_scene_root()
	var current_path := String(current.scene_file_path) if current else ""
	if current_path == desired:
		_scene_switch_in_flight = false
		_scene_switch_target = ""
		_scene_switch_frames_left = 0
		_scene_switch_retries = 0
		if _pending_scene_path == desired:
			_pending_scene_path = ""
			_pending_selection_restore = null
		if _pending_scene_path != "":
			_defer_scene_switch()
		return

	_scene_switch_frames_left -= 1
	if _scene_switch_frames_left <= 0:
		_scene_switch_in_flight = false
		_scene_switch_target = ""
		if _pending_scene_path == desired and _scene_switch_retries < _SCENE_SWITCH_MAX_RETRIES:
			_scene_switch_retries += 1
			_defer_scene_switch()
		else:
			_scene_switch_retries = 0
		return

	call_deferred("_poll_scene_switch")


func _restore_resource_selection_when_ready(
    object: Object,
    desired_scene_path: String,
    max_frames: int
) -> void:
	var current = EditorInterface.get_edited_scene_root()
	if current and String(current.scene_file_path) == desired_scene_path:
		if current.has_method("_rebuild_world"):
			current.call("_rebuild_world")
		var selection = EditorInterface.get_selection()
		if selection != null:
			selection.clear()
		EditorInterface.edit_resource(object)
		update_overlays()
		return
	if max_frames <= 0:
		if current and current.has_method("_rebuild_world"):
			current.call("_rebuild_world")
		var selection2 = EditorInterface.get_selection()
		if selection2 != null:
			selection2.clear()
		EditorInterface.edit_resource(object)
		update_overlays()
		return
	call_deferred("_restore_resource_selection_when_ready", object, desired_scene_path, max_frames - 1)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not edit_mode or current_obj == null or current_kind == Kind.NONE:
		return false

	# If the wrong scene is open, consume the click and queue a switch.
	if event is InputEventMouseButton:
		var path := _get_target_scene_path()
		if path != "":
			var scene_root = EditorInterface.get_edited_scene_root()
			var current_path := String(scene_root.scene_file_path) if scene_root else ""
			var mb := event as InputEventMouseButton
			if mb.pressed and current_path != "" and current_path != path:
				_request_open_level_for_current()
				return true

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

	# Only draw if correct level is open (tolerate empty current_path).
	var target_path := _get_target_scene_path()
	if target_path != "":
		var scene_root = EditorInterface.get_edited_scene_root()
		var current_path := String(scene_root.scene_file_path) if scene_root else ""
		if current_path != "" and current_path != target_path:
			return

	if current_kind == Kind.SPAWN_POINT:
		_draw_spawn_overlay(overlay)
	elif current_kind == Kind.ROUTE:
		_draw_route_overlay(overlay)


# --- Spawn ---
func _spawn_forward_input(event: InputEvent) -> bool:
	var sp := current_obj as SpawnPointData
	if sp == null:
		return false

	if event is InputEventMouseButton:
		return _spawn_handle_mouse_click(event as InputEventMouseButton, sp)
	if event is InputEventMouseMotion and _spawn_dragging:
		var mm := event as InputEventMouseMotion
		var mouse_pos = _get_mouse_position_world(mm.position)
		sp.position = _snap_to_grid(mouse_pos)
		update_overlays()
		return true
	return false


func _spawn_handle_mouse_click(mb: InputEventMouseButton, sp: SpawnPointData) -> bool:
	var mouse_pos = _get_mouse_position_world(mb.position)
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false

	if mb.pressed:
		var handle_pos = _get_wp_global_pos(sp)
		var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
		var screen_handle = viewport_trans * handle_pos
		var screen_click = viewport_trans * mouse_pos
		if screen_handle.distance_to(screen_click) < HANDLE_RADIUS_SPAWN + 4.0:
			_spawn_dragging = true
			_spawn_drag_start = sp.position # Local position
			return true

		var new_wp = _get_world_point_from_mouse(mouse_pos)
		_spawn_set_wp(new_wp, sp)
		return true

	# release
	if _spawn_dragging:
		_spawn_end_drag(sp)
		_spawn_dragging = false
		return true

	return false


func _spawn_set_wp(wp: WorldPoint, sp: SpawnPointData) -> void:
	var ur = get_undo_redo()
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
	var ur = get_undo_redo()
	ur.create_action("Move Spawn Point")
	var final_pos = sp.position
	ur.add_do_property(sp, "position", final_pos)
	ur.add_undo_property(sp, "position", _spawn_drag_start)
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


func _draw_spawn_overlay(overlay: Control) -> void:
	var sp := current_obj as SpawnPointData
	if sp == null:
		return

	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var global_pos = _get_wp_global_pos(sp)
	var screen_pos = viewport_trans * global_pos

	var cross_size = 20.0
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

	var label = "Spawn Point"
	if sp.display_name != "":
		label = sp.display_name
	overlay.draw_string(
		ThemeDB.get_fallback_font(),
		screen_pos + Vector2(15, -15),
		"%s (Level %s)\n(%d, %d)" % [label, sp.level_id, int(sp.position.x), int(sp.position.y)],
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
		var mouse_pos = _get_mouse_position_world(mm.position)

		var old_hover = _route_hovered_point_index
		var old_seg_hover = _route_hovered_segment_index

		_route_hovered_point_index = _route_get_point_at(mouse_pos, r)
		_route_hovered_segment_index = -1
		if _route_hovered_point_index == -1:
			_route_hovered_segment_index = _route_get_segment_at(mouse_pos, r)

		if _route_hovered_point_index != old_hover or _route_hovered_segment_index != old_seg_hover:
			update_overlays()

		if _route_dragged_point_index != -1:
			var wps = r.waypoints.duplicate()
			var wp = _get_world_point_from_mouse(mouse_pos)

			# Ensure we are not modifying the original resource in the array directly
			# if it's shared, but here we just want to update the dragged one.
			var dragged_wp = WorldPoint.new()
			dragged_wp.level_id = wp.level_id
			dragged_wp.position = wp.position
			wps[_route_dragged_point_index] = dragged_wp
			r.waypoints = wps
			update_overlays()
			return true

	return false


func _route_handle_mouse_click(mb: InputEventMouseButton, r: RouteResource) -> bool:
	var mouse_pos = _get_mouse_position_world(mb.position)

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var clicked_idx = _route_get_point_at(mouse_pos, r)
			if clicked_idx != -1:
				_route_dragged_point_index = clicked_idx
				var original = r.waypoints[clicked_idx]
				_route_drag_start_wp = WorldPoint.new()
				_route_drag_start_wp.level_id = original.level_id
				_route_drag_start_wp.position = original.position
				return true

			var seg_idx = _route_get_segment_at(mouse_pos, r)
			var wp = _get_world_point_from_mouse(mouse_pos)
			if seg_idx != -1:
				_route_insert_wp(seg_idx + 1, wp, r)
				_route_dragged_point_index = seg_idx + 1
				_route_drag_start_wp = wp
				return true

			_route_add_wp(wp, r)
			_route_dragged_point_index = r.waypoints.size() - 1
			_route_drag_start_wp = wp
			return true

		# release
		if _route_dragged_point_index != -1:
			_route_end_drag_wp(_route_dragged_point_index, r)
			_route_dragged_point_index = -1
			_route_drag_start_wp = null
			return true

	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var clicked_idx2 = _route_get_point_at(mouse_pos, r)
		if clicked_idx2 != -1:
			_route_delete_wp(clicked_idx2, r)
			return true

	return false


func _draw_route_overlay(overlay: Control) -> void:
	var r := current_obj as RouteResource
	if r == null:
		return

	if not edit_mode:
		_route_hovered_point_index = -1
		_route_hovered_segment_index = -1

	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var wps = r.waypoints
	var count = wps.size()

	if count == 0:
		overlay.draw_string(
			ThemeDB.get_fallback_font(),
			Vector2(50, 50),
			"Click to add start point (WorldPoints)" if edit_mode else "No route points",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.YELLOW
		)
		return

	for i in range(count - 1):
		var p1 = viewport_trans * _get_wp_global_pos(wps[i])
		var p2 = viewport_trans * _get_wp_global_pos(wps[i + 1])
		var color = Color.CYAN
		if wps[i].level_id != wps[i+1].level_id:
			color = Color.MAGENTA # Visual hint for level transition
		var width = 2.0
		if edit_mode and i == _route_hovered_segment_index:
			color = Color.YELLOW
			width = 4.0
		overlay.draw_line(p1, p2, color, width)

	for i in range(count):
		var p = viewport_trans * _get_wp_global_pos(wps[i])
		var colorp = Color.WHITE
		var radius = HANDLE_RADIUS_ROUTE
		if edit_mode and i == _route_hovered_point_index:
			colorp = Color.GREEN
			radius = HANDLE_RADIUS_ROUTE * 1.2
		if edit_mode and i == _route_dragged_point_index:
			colorp = Color.RED
		overlay.draw_circle(p, radius, colorp)
		overlay.draw_circle(p, radius * 0.8, Color.BLACK)
		overlay.draw_string(
			ThemeDB.get_fallback_font(),
			p + Vector2(10, -10),
			"%d (L%d)" % [i, wps[i].level_id],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14
		)


# --- Common helpers ---
func _get_mouse_position_world(screen_pos: Vector2) -> Vector2:
	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	return viewport_trans.affine_inverse() * screen_pos


func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x), round(pos.y))


func _route_get_point_at(world_pos: Vector2, r: RouteResource) -> int:
	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var screen_click = viewport_trans * world_pos
	var wps = r.waypoints
	for i in range(wps.size()):
		var p_screen = viewport_trans * _get_wp_global_pos(wps[i])
		if p_screen.distance_to(screen_click) < HANDLE_RADIUS_ROUTE + 2.0:
			return i
	return -1


func _route_get_segment_at(world_pos: Vector2, r: RouteResource) -> int:
	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
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
	var ur = get_undo_redo()
	ur.create_action("Add Route Waypoint")
	var new_wps = r.waypoints.duplicate()
	new_wps.append(wp)
	ur.add_do_property(r, "waypoints", new_wps)
	ur.add_undo_property(r, "waypoints", r.waypoints.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


func _route_insert_wp(idx: int, wp: WorldPoint, r: RouteResource) -> void:
	var ur = get_undo_redo()
	ur.create_action("Insert Route Waypoint")
	var new_wps = r.waypoints.duplicate()
	new_wps.insert(idx, wp)
	ur.add_do_property(r, "waypoints", new_wps)
	ur.add_undo_property(r, "waypoints", r.waypoints.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


func _route_end_drag_wp(idx: int, r: RouteResource) -> void:
	var current = r.waypoints[idx]
	if (_route_drag_start_wp.level_id == current.level_id
	and _route_drag_start_wp.position == current.position):
		return
	var ur = get_undo_redo()
	ur.create_action("Move Route Waypoint")

	# We need to deep copy the waypoints for undo/redo to work correctly with sub-resources
	var final_wps = []
	for wp in r.waypoints:
		var copy = WorldPoint.new()
		copy.level_id = wp.level_id
		copy.position = wp.position
		final_wps.append(copy)

	var initial_wps = []
	for i in range(r.waypoints.size()):
		var wp = r.waypoints[i]
		var copy = WorldPoint.new()
		if i == idx:
			copy.level_id = _route_drag_start_wp.level_id
			copy.position = _route_drag_start_wp.position
		else:
			copy.level_id = wp.level_id
			copy.position = wp.position
		initial_wps.append(copy)

	ur.add_do_property(r, "waypoints", final_wps)
	ur.add_undo_property(r, "waypoints", initial_wps)
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


func _route_delete_wp(idx: int, r: RouteResource) -> void:
	var ur = get_undo_redo()
	ur.create_action("Delete Route Waypoint")
	var new_wps = r.waypoints.duplicate()
	new_wps.remove_at(idx)
	ur.add_do_property(r, "waypoints", new_wps)
	ur.add_undo_property(r, "waypoints", r.waypoints.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()
