@tool
extends Control

const _WORLD_MAP_SCENE := "res://debug/world_map/world_map_editor.tscn"
const _DEFAULT_LAYOUT := preload("res://debug/world_map/default_layout.tres")
const _ROUTES_DIR := "res://game/data/routes"
const _SPAWNPOINTS_DIR := "res://game/data/spawn_points"

var _plugin: EditorPlugin = null
var _editor_interface: EditorInterface = null
var _undo: EditorUndoRedoManager = null

var _tree: Tree = null
var _search: LineEdit = null
var _btn_edit: CheckButton = null
var _lbl_selected: Label = null
var _sv_container: SubViewportContainer = null
var _sv: SubViewport = null
var _world_instance: Node2D = null
var _overlay: Control = null
var _camera: Camera2D = null
var _sv_debug_label: Label = null
var _panning: bool = false
var _pan_last_mouse: Vector2 = Vector2.ZERO
var _pan_space_held: bool = false
var _space_pan_active: bool = false

var _help_panel: PanelContainer = null
var _help_label: Label = null

var _invert_scroll: bool = false
var _pending_focus: bool = false
var _resize_sync_frames_left: int = 0

var _selected_path: String = ""
var _selected_obj: Object = null

var _edit_enabled: bool = false
var _spawn_dragging: bool = false
var _spawn_drag_start: Vector2 = Vector2.ZERO
var _route_dragged_point_index: int = -1
var _route_drag_start_wp: WorldPoint = null
var _route_hovered_point_index: int = -1
var _route_hovered_segment_index: int = -1

const HANDLE_RADIUS_SPAWN := 10.0
const HANDLE_RADIUS_ROUTE := 8.0
const CLICK_THRESHOLD_ROUTE := 10.0

func set_plugin_reference(plugin: EditorPlugin) -> void:
	_plugin = plugin

func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface

func set_undo_redo(undo: EditorUndoRedoManager) -> void:
	_undo = undo

func _ready() -> void:
	_build_ui()
	_refresh()
	# Defer until the control has a real size (important for SubViewportContainer stretch).
	call_deferred("_poll_embedded_viewport_ready", 60)
	_sync_tree_selection()
	# Keep embedded viewport sized even if some containers don't emit resized reliably.
	resized.connect(_sync_viewport_size)
	set_process(true)

func _process(_delta: float) -> void:
	# Some editor layouts don't emit resized consistently; keep syncing briefly after rebuild.
	if _resize_sync_frames_left > 0:
		_resize_sync_frames_left -= 1
		_sync_viewport_size()
	if _pending_focus:
		_pending_focus = false
		_focus_camera_on_selection()


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	_resize_sync_frames_left = 30

	var root := HBoxContainer.new()
	# This tab extends Control (not a Container), so size_flags won't auto-layout.
	# Anchor the root container to fill so the content stretches with the tab.
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	add_child(root)

	var left_panel := PanelContainer.new()
	# Make the left "world" panel (spawns/routes list) a bit larger by default.
	left_panel.custom_minimum_size = Vector2(430, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left_panel)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left)

	var top := HBoxContainer.new()
	left.add_child(top)

	var btn_refresh := Button.new()
	btn_refresh.text = "Refresh"
	btn_refresh.pressed.connect(_refresh)
	top.add_child(btn_refresh)

	_search = LineEdit.new()
	_search.placeholder_text = "Filter (name/path)…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void:
		_refresh()
	)
	top.add_child(_search)

	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.columns = 1
	_tree.set_column_expand(0, true)
	_tree.set_column_custom_minimum_width(0, 360)
	_tree.item_selected.connect(_on_tree_selected)
	left.add_child(_tree)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right)

	var header := HBoxContainer.new()
	right.add_child(header)

	_btn_edit = CheckButton.new()
	_btn_edit.text = "Edit"
	_btn_edit.tooltip_text = "Enable click/drag editing in the embedded map."
	_btn_edit.disabled = true
	_btn_edit.toggled.connect(func(v: bool) -> void:
		_set_edit_enabled(v)
	)
	header.add_child(_btn_edit)

	var btn_center := Button.new()
	btn_center.text = "Center"
	btn_center.tooltip_text = "Center camera on current selection."
	btn_center.pressed.connect(_focus_camera_on_selection)
	header.add_child(btn_center)

	var btn_reset_zoom := Button.new()
	btn_reset_zoom.text = "Reset Zoom"
	btn_reset_zoom.pressed.connect(func() -> void:
		if _camera != null:
			_camera.zoom = Vector2(0.5, 0.5)
			_pending_focus = true
			if _overlay != null:
				_overlay.queue_redraw()
	)
	header.add_child(btn_reset_zoom)

	var cb_invert := CheckButton.new()
	cb_invert.text = "Invert scroll"
	cb_invert.button_pressed = _invert_scroll
	cb_invert.toggled.connect(func(v: bool) -> void:
		_invert_scroll = v
	)
	header.add_child(cb_invert)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var btn_help := Button.new()
	btn_help.text = "Help"
	btn_help.pressed.connect(func() -> void:
		if _help_panel != null:
			_help_panel.visible = not _help_panel.visible
	)
	header.add_child(btn_help)

	_sv_container = SubViewportContainer.new()
	_sv_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sv_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Manual sizing is more reliable across editor layouts; we keep _sv.size synced.
	_sv_container.stretch = false
	right.add_child(_sv_container)

	_sv = SubViewport.new()
	_sv.disable_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv_container.add_child(_sv)
	call_deferred("_sync_viewport_size")

	# Camera so we can pan/zoom inside embedded viewport.
	_camera = Camera2D.new()
	_camera.position = Vector2.ZERO
	# Default zoom-in so the world is readable.
	_camera.zoom = Vector2(0.5, 0.5)
	_camera.enabled = true
	_sv.add_child(_camera)
	# Godot 4: use make_current() (no `current` property).
	_camera.call_deferred("make_current")

	# Debug label to verify SubViewport rendering.
	_sv_debug_label = Label.new()
	_sv_debug_label.text = "SV OK"
	_sv_debug_label.position = Vector2(16, 16)
	_sv_debug_label.modulate = Color(0.6, 1.0, 0.6, 0.9)
	_sv.add_child(_sv_debug_label)

	_sv_container.resized.connect(func() -> void:
		_sync_viewport_size()
	)

	_overlay = Control.new()
	_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay.size = _sv_container.size
	# Always capture input over the embedded map so pan/zoom works reliably,
	# even when edit mode is off.
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_gui_input)
	_overlay.draw.connect(_on_overlay_draw)
	_sv_container.add_child(_overlay)

	_help_panel = PanelContainer.new()
	_help_panel.visible = false
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_panel.position = Vector2(10, 10)
	_help_panel.custom_minimum_size = Vector2(260, 0)
	_sv_container.add_child(_help_panel)

	var hv := VBoxContainer.new()
	_help_panel.add_child(hv)
	_help_label = Label.new()
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.text = """SpawnPoint:
- L-Click: set position
- Drag handle: move

Route:
- L-Click: add/move
- R-Click: delete
- Click segment: insert

Navigation:
- MMB drag: pan
- Mouse wheel: zoom
- Trackpad: two-finger pan, pinch zoom
- Space + LMB drag: pan
"""
	hv.add_child(_help_label)

	_lbl_selected = Label.new()
	_lbl_selected.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_selected.text = "No selection"
	right.add_child(_lbl_selected)


func select_resource(object: Object) -> void:
	if object == null:
		return
	_selected_obj = object
	_selected_path = object.resource_path if object is Resource else ""
	_update_selected_ui()
	if _plugin != null and _plugin.has_method("set_current_object"):
		_plugin.call("set_current_object", object)
	_sync_tree_selection()
	if _overlay != null:
		_overlay.queue_redraw()
	_pending_focus = true

func _refresh() -> void:
	if _tree == null:
		return

	_tree.clear()
	var root := _tree.create_item()

	var filter := ""
	if _search != null:
		filter = _search.text.to_lower()

	var sp_root := _tree.create_item(root)
	sp_root.set_text(0, "Spawn Points")
	sp_root.collapsed = false

	var route_root := _tree.create_item(root)
	route_root.set_text(0, "Routes")
	route_root.collapsed = false

	for p in _list_resources(_SPAWNPOINTS_DIR, filter):
		var it := _tree.create_item(sp_root)
		it.set_text(0, _short_label(p))
		it.set_metadata(0, p)
		it.set_tooltip_text(0, p)

	for p2 in _list_resources(_ROUTES_DIR, filter):
		var it2 := _tree.create_item(route_root)
		it2.set_text(0, _short_label(p2))
		it2.set_metadata(0, p2)
		it2.set_tooltip_text(0, p2)

	# Re-select current item after refresh (best-effort).
	_sync_tree_selection(root)

	_update_selected_ui()


func _on_tree_selected() -> void:
	if _tree == null:
		return
	var it := _tree.get_selected()
	if it == null:
		return
	var path := str(it.get_metadata(0))
	if path.is_empty():
		return

	var res := load(path)
	if res == null:
		return

	_selected_obj = res
	_selected_path = path

	if _plugin != null and _plugin.has_method("set_current_object"):
		_plugin.call("set_current_object", res)

	_update_selected_ui()
	if _overlay != null:
		_overlay.queue_redraw()
	_pending_focus = true


func _update_selected_ui() -> void:
	var has_sel := _selected_obj != null
	if _btn_edit != null:
		_btn_edit.disabled = not has_sel

	if _lbl_selected != null:
		if not has_sel:
			_lbl_selected.text = "No selection"
		else:
			_lbl_selected.text = "Selected:\n%s" % _selected_path

	if _btn_edit != null:
		_btn_edit.set_pressed_no_signal(_edit_enabled)


func _find_item_with_metadata(root_item: TreeItem, value: String) -> TreeItem:
	if root_item == null:
		return null
	var c := root_item.get_first_child()
	while c != null:
		var md := c.get_metadata(0)
		if md != null and str(md) == value:
			return c
		var inner := _find_item_with_metadata(c, value)
		if inner != null:
			return inner
		c = c.get_next()
	return null


func _sync_tree_selection(root_item: TreeItem = null) -> void:
	if _tree == null:
		return
	if root_item == null:
		root_item = _tree.get_root()
	if root_item == null:
		return
	if _selected_path.is_empty():
		return
	var found := _find_item_with_metadata(root_item, _selected_path)
	if found != null:
		found.select(0)
	else:
		# If we couldn't find it (e.g. list not built yet), rebuild once.
		if root_item == _tree.get_root():
			_refresh()


func _set_edit_enabled(v: bool) -> void:
	_edit_enabled = v
	if _overlay != null:
		_overlay.queue_redraw()


func _list_resources(base_dir: String, filter: String) -> PackedStringArray:
	var out := PackedStringArray()
	_collect_tres(base_dir, out)

	var filtered := PackedStringArray()
	if filter.is_empty():
		return _filter_by_expected_type(base_dir, out)

	for p in out:
		var pl := str(p).to_lower()
		if pl.contains(filter):
			filtered.append(p)
	return _filter_by_expected_type(base_dir, filtered)


func _filter_by_expected_type(base_dir: String, paths: PackedStringArray) -> PackedStringArray:
	# Filter out non-editable resources, e.g. spawn_catalog.tres.
	var out := PackedStringArray()
	for p in paths:
		var res := load(p)
		if base_dir == _SPAWNPOINTS_DIR:
			if res is SpawnPointData:
				out.append(p)
		elif base_dir == _ROUTES_DIR:
			if res is RouteResource:
				out.append(p)
		else:
			out.append(p)
	return out


func _collect_tres(dir: String, out: PackedStringArray) -> void:
	if dir.is_empty():
		return
	if not DirAccess.dir_exists_absolute(dir):
		return

	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect_tres(dir.path_join(d), out)


func _short_label(path: String) -> String:
	if path.is_empty():
		return ""
	var dir := path.get_base_dir().get_file()
	var file := path.get_file()
	return file if dir.is_empty() else "%s/%s" % [dir, file]


func _ensure_world_map_loaded() -> void:
	if _sv == null:
		return
	if _world_instance != null and is_instance_valid(_world_instance):
		return
	if not FileAccess.file_exists(_WORLD_MAP_SCENE):
		return
	var ps := load(_WORLD_MAP_SCENE)
	if ps == null or not (ps is PackedScene):
		return
	_world_instance = (ps as PackedScene).instantiate()
	_sv.add_child(_world_instance)
	if _world_instance.has_method("_rebuild_world"):
		_world_instance.call_deferred("_rebuild_world")
	if _camera != null:
		_camera.call_deferred("make_current")
	_focus_camera_on_selection()


func _poll_embedded_viewport_ready(frames_left: int) -> void:
	# When SubViewportContainer.stretch is enabled, it manages viewport sizing.
	# Wait until this control has a real size before instantiating the world scene.
	if _sv_container != null and _sv_container.size.x >= 8 and _sv_container.size.y >= 8:
		if _overlay != null:
			_overlay.size = _sv_container.size
		_ensure_world_map_loaded()
		return
	if frames_left <= 0:
		_ensure_world_map_loaded()
		return
	call_deferred("_poll_embedded_viewport_ready", frames_left - 1)


func _sync_viewport_size() -> void:
	if _sv_container == null or _sv == null:
		return
	var s := _sv_container.size
	if s.x < 8 or s.y < 8:
		return
	var target := Vector2i(int(s.x), int(s.y))
	if _sv.size != target:
		_sv.size = target
	if _overlay != null:
		_overlay.size = s


func _get_layout() -> WorldEditorLayout:
	if _world_instance == null or not is_instance_valid(_world_instance):
		if _DEFAULT_LAYOUT is WorldEditorLayout:
			return _DEFAULT_LAYOUT as WorldEditorLayout
		return null
	if "layout" in _world_instance:
		return _world_instance.get("layout") as WorldEditorLayout
	if _DEFAULT_LAYOUT is WorldEditorLayout:
		return _DEFAULT_LAYOUT as WorldEditorLayout
	return null


func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x), round(pos.y))


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var t := _get_viewport_canvas_transform()
	return t * world_pos


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var t := _get_viewport_canvas_transform()
	return t.affine_inverse() * screen_pos


func _get_viewport_canvas_transform() -> Transform2D:
	# When a Camera2D is current, it drives the SubViewport's canvas transform.
	if _sv != null:
		if "canvas_transform" in _sv:
			return _sv.canvas_transform
		if _sv.has_method("get_canvas_transform"):
			return _sv.call("get_canvas_transform")
	# Fallback: approximate with camera.
	if _camera != null:
		return _camera.get_canvas_transform()
	return Transform2D()


func _focus_camera_on_selection() -> void:
	if _camera == null or _selected_obj == null:
		return
	var wp: WorldPoint = null
	if _selected_obj is SpawnPointData:
		wp = _selected_obj as SpawnPointData
	elif _selected_obj is RouteResource:
		var r := _selected_obj as RouteResource
		if r != null and not r.waypoints.is_empty():
			wp = r.waypoints[0]
	if wp == null:
		return
	# Ensure the camera is current before centering.
	# Selection can happen before deferred make_current runs.
	if _camera.has_method("make_current"):
		_camera.make_current()
	_camera.position = _get_wp_global_pos(wp)
	if _overlay != null:
		# Defer redraw so the viewport/camera transform is updated first.
		_overlay.call_deferred("queue_redraw")

func _zoom_at(screen_pos: Vector2, zoom_factor: float) -> void:
	if _camera == null:
		return
	if zoom_factor <= 0.0:
		return
	var before := _screen_to_world(screen_pos)
	_camera.zoom *= Vector2(zoom_factor, zoom_factor)
	# Clamp to avoid crazy values.
	_camera.zoom.x = clampf(_camera.zoom.x, 0.1, 10.0)
	_camera.zoom.y = clampf(_camera.zoom.y, 0.1, 10.0)
	var after := _screen_to_world(screen_pos)
	_camera.position += (before - after)
	if _overlay != null:
		_overlay.queue_redraw()

func _get_world_point_from_mouse(mouse_pos: Vector2) -> WorldPoint:
	var wp := WorldPoint.new()
	var layout := _get_layout()
	if layout == null:
		wp.position = _snap_to_grid(_screen_to_world(mouse_pos))
		return wp

	var world_pos := _screen_to_world(mouse_pos)
	var best_level := Enums.Levels.NONE
	var best_local_pos := world_pos
	var min_dist := INF
	for level_id_var in layout.level_offsets.keys():
		var level_id := int(level_id_var)
		var offset: Vector2 = layout.get_level_offset(level_id)
		var dist: float = world_pos.distance_to(offset)
		if dist < min_dist:
			min_dist = dist
			best_level = level_id
			best_local_pos = world_pos - offset
	wp.level_id = best_level
	wp.position = _snap_to_grid(best_local_pos)
	return wp


func _get_wp_global_pos(wp: WorldPoint) -> Vector2:
	if wp == null:
		return Vector2.ZERO
	var layout := _get_layout()
	if layout == null:
		return wp.position
	return wp.position + layout.get_level_offset(wp.level_id)


func _on_overlay_gui_input(event: InputEvent) -> void:
	# Pan/zoom always available in embedded map.
	var handled_nav := false
	# Key events don't always reach this control; use Input as a fallback.
	_pan_space_held = Input.is_key_pressed(KEY_SPACE)

	# Trackpad: two-finger pan + pinch zoom.
	if event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		if _camera != null:
			var d := pg.delta * (-1.0 if _invert_scroll else 1.0)
			var zx := maxf(0.001, _camera.zoom.x)
			var zy := maxf(0.001, _camera.zoom.y)
			_camera.position -= Vector2(d.x / zx, d.y / zy)
			_overlay.queue_redraw()
		return
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		var f := mg.factor
		if f > 0.0:
			_zoom_at(mg.position, (f if _invert_scroll else (1.0 / f)))
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			_pan_last_mouse = mb.position
			handled_nav = true
		elif mb.button_index == MOUSE_BUTTON_LEFT and _pan_space_held:
			_space_pan_active = mb.pressed
			_panning = _space_pan_active
			_pan_last_mouse = mb.position
			handled_nav = true
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			# Default: wheel-up zooms IN (invertable).
			var f := 1.1 if not _invert_scroll else 0.9
			_zoom_at(mb.position, f)
			handled_nav = true
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			# Default: wheel-down zooms OUT (invertable).
			var f2 := 0.9 if not _invert_scroll else 1.1
			_zoom_at(mb.position, f2)
			handled_nav = true

	if event is InputEventMouseMotion and _panning:
		var mm := event as InputEventMouseMotion
		if _camera != null:
			var delta := mm.position - _pan_last_mouse
			_pan_last_mouse = mm.position
			# Keep perceived pan speed consistent across zoom levels:
			# higher zoom => smaller world-space movement per pixel.
			var zx := maxf(0.001, _camera.zoom.x)
			var zy := maxf(0.001, _camera.zoom.y)
			_camera.position -= Vector2(delta.x / zx, delta.y / zy)
			_overlay.queue_redraw()
		handled_nav = true

	if handled_nav:
		return

	if not _edit_enabled or _selected_obj == null:
		return

	if _selected_obj is SpawnPointData:
		_spawn_input(event, _selected_obj as SpawnPointData)
	elif _selected_obj is RouteResource:
		_route_input(event, _selected_obj as RouteResource)


func _spawn_input(event: InputEvent, sp: SpawnPointData) -> void:
	if sp == null:
		return

	if event is InputEventMouseMotion and _spawn_dragging:
		var mm := event as InputEventMouseMotion
		var wp := _get_world_point_from_mouse(mm.position)
		_apply_spawn_point_warp(sp, wp, true)
		_overlay.queue_redraw()
		return

	if not (event is InputEventMouseButton):
		return

	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if mb.pressed:
		var handle_pos := _world_to_screen(_get_wp_global_pos(sp))
		if handle_pos.distance_to(mb.position) < HANDLE_RADIUS_SPAWN + 4.0:
			_spawn_dragging = true
			_spawn_drag_start = sp.position
			return
		var wp2 := _get_world_point_from_mouse(mb.position)
		_apply_spawn_point_warp(sp, wp2, false)
		_overlay.queue_redraw()
		return

	# release
	if _spawn_dragging:
		_spawn_dragging = false
		_overlay.queue_redraw()


func _apply_spawn_point_warp(sp: SpawnPointData, wp: WorldPoint, continuous: bool) -> void:
	if sp == null or wp == null:
		return
	if _undo == null or continuous:
		sp.level_id = wp.level_id
		sp.position = wp.position
		return
	_undo.create_action("Set Spawn Point WorldPoint")
	_undo.add_do_property(sp, "level_id", wp.level_id)
	_undo.add_do_property(sp, "position", wp.position)
	_undo.add_undo_property(sp, "level_id", sp.level_id)
	_undo.add_undo_property(sp, "position", sp.position)
	_undo.commit_action()


func _route_input(event: InputEvent, r: RouteResource) -> void:
	if r == null:
		return

	var needs_redraw := false

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_route_hovered_point_index = _route_get_point_at(mm.position, r)
		_route_hovered_segment_index = -1
		if _route_hovered_point_index == -1:
			_route_hovered_segment_index = _route_get_segment_at(mm.position, r)

		if _route_dragged_point_index != -1:
			var wps := r.waypoints.duplicate()
			var wp := _get_world_point_from_mouse(mm.position)
			var dragged_wp := WorldPoint.new()
			dragged_wp.level_id = wp.level_id
			dragged_wp.position = wp.position
			wps[_route_dragged_point_index] = dragged_wp
			r.waypoints = wps
		needs_redraw = true

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var mouse_pos := mb.position

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var clicked_idx := _route_get_point_at(mouse_pos, r)
				if clicked_idx != -1:
					_route_dragged_point_index = clicked_idx
					var original := r.waypoints[clicked_idx]
					_route_drag_start_wp = WorldPoint.new()
					_route_drag_start_wp.level_id = original.level_id
					_route_drag_start_wp.position = original.position
					needs_redraw = true
				else:
					var seg_idx := _route_get_segment_at(mouse_pos, r)
					var wp2 := _get_world_point_from_mouse(mouse_pos)
					if seg_idx != -1:
						_route_insert_wp(seg_idx + 1, wp2, r)
						_route_dragged_point_index = seg_idx + 1
						_route_drag_start_wp = wp2
					else:
						_route_add_wp(wp2, r)
						_route_dragged_point_index = r.waypoints.size() - 1
						_route_drag_start_wp = wp2
					needs_redraw = true
			else:
				# release
				if _route_dragged_point_index != -1:
					_route_end_drag_wp(_route_dragged_point_index, r)
					_route_dragged_point_index = -1
					_route_drag_start_wp = null
					needs_redraw = true

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var clicked_idx2 := _route_get_point_at(mouse_pos, r)
			if clicked_idx2 != -1:
				_route_delete_wp(clicked_idx2, r)
				needs_redraw = true

	if needs_redraw and _overlay != null:
		_overlay.queue_redraw()


func _route_get_point_at(world_pos: Vector2, r: RouteResource) -> int:
	var world := _screen_to_world(world_pos)
	var wps := r.waypoints
	for i in range(wps.size()):
		var p_screen := _get_wp_global_pos(wps[i])
		if p_screen.distance_to(world) < HANDLE_RADIUS_ROUTE + 2.0:
			return i
	return -1


func _route_get_segment_at(world_pos: Vector2, r: RouteResource) -> int:
	var world := _screen_to_world(world_pos)
	var wps := r.waypoints
	if wps.size() < 2:
		return -1
	for i in range(wps.size() - 1):
		var p1 := _get_wp_global_pos(wps[i])
		var p2 := _get_wp_global_pos(wps[i + 1])
		var closest := Geometry2D.get_closest_point_to_segment(world, p1, p2)
		if closest.distance_to(world) < CLICK_THRESHOLD_ROUTE:
			return i
	return -1


func _route_add_wp(wp: WorldPoint, r: RouteResource) -> void:
	if _undo == null:
		var new_wps := r.waypoints.duplicate()
		new_wps.append(wp)
		r.waypoints = new_wps
		return
	_undo.create_action("Add Route Waypoint")
	var new_wps2 := r.waypoints.duplicate()
	new_wps2.append(wp)
	_undo.add_do_property(r, "waypoints", new_wps2)
	_undo.add_undo_property(r, "waypoints", r.waypoints.duplicate())
	_undo.commit_action()


func _route_insert_wp(idx: int, wp: WorldPoint, r: RouteResource) -> void:
	if _undo == null:
		var new_wps := r.waypoints.duplicate()
		new_wps.insert(idx, wp)
		r.waypoints = new_wps
		return
	_undo.create_action("Insert Route Waypoint")
	var new_wps2 := r.waypoints.duplicate()
	new_wps2.insert(idx, wp)
	_undo.add_do_property(r, "waypoints", new_wps2)
	_undo.add_undo_property(r, "waypoints", r.waypoints.duplicate())
	_undo.commit_action()


func _route_end_drag_wp(idx: int, r: RouteResource) -> void:
	if _route_drag_start_wp == null:
		return
	var current := r.waypoints[idx]
	if (
		_route_drag_start_wp.level_id == current.level_id
		and _route_drag_start_wp.position == current.position
	):
		return
	if _undo == null:
		return
	_undo.create_action("Move Route Waypoint")

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

	_undo.add_do_property(r, "waypoints", final_wps)
	_undo.add_undo_property(r, "waypoints", initial_wps)
	_undo.commit_action()


func _route_delete_wp(idx: int, r: RouteResource) -> void:
	if _undo == null:
		var new_wps := r.waypoints.duplicate()
		new_wps.remove_at(idx)
		r.waypoints = new_wps
		return
	_undo.create_action("Delete Route Waypoint")
	var new_wps2 := r.waypoints.duplicate()
	new_wps2.remove_at(idx)
	_undo.add_do_property(r, "waypoints", new_wps2)
	_undo.add_undo_property(r, "waypoints", r.waypoints.duplicate())
	_undo.commit_action()


func _on_overlay_draw() -> void:
	if _overlay == null or _selected_obj == null:
		return
	_draw_layout_background(_overlay)
	if _selected_obj is SpawnPointData:
		_draw_spawn_overlay(_overlay, _selected_obj as SpawnPointData)
	elif _selected_obj is RouteResource:
		_draw_route_overlay(_overlay, _selected_obj as RouteResource)


func _draw_layout_background(overlay: Control) -> void:
	var layout := _get_layout()
	if layout == null:
		return

	# Draw a simple grid + level origins so the user can place points without
	# needing the heavy merged-level scene to render.
	var grid_step := 128.0
	var grid_color := Color(0.25, 0.25, 0.25, 0.35)
	var w := float(overlay.size.x)
	var h := float(overlay.size.y)

	var origin := _world_to_screen(Vector2.ZERO)
	var start_x := fmod(origin.x, grid_step)
	var start_y := fmod(origin.y, grid_step)
	if start_x < 0: start_x += grid_step
	if start_y < 0: start_y += grid_step

	var x := start_x
	while x <= w:
		overlay.draw_line(Vector2(x, 0), Vector2(x, h), grid_color, 1.0)
		x += grid_step
	var y := start_y
	while y <= h:
		overlay.draw_line(Vector2(0, y), Vector2(w, y), grid_color, 1.0)
		y += grid_step

	# Level markers
	for level_id_var in layout.level_offsets.keys():
		var level_id := int(level_id_var)
		var off := layout.get_level_offset(level_id)
		var p := _world_to_screen(off)
		overlay.draw_circle(p, 6.0, Color(1, 1, 0, 0.8))
		overlay.draw_string(
			ThemeDB.get_fallback_font(),
			p + Vector2(8, -8),
			"L%d" % level_id,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(1, 1, 0.8, 0.9)
		)


func _draw_spawn_overlay(overlay: Control, sp: SpawnPointData) -> void:
	if sp == null:
		return
	var global_pos := _world_to_screen(_get_wp_global_pos(sp))
	var color := Color(0.8, 0.8, 0.8)
	if _edit_enabled:
		color = Color.LIME if not _spawn_dragging else Color.RED
	var cross_size := 20.0
	overlay.draw_line(
		global_pos - Vector2(cross_size, 0),
		global_pos + Vector2(cross_size, 0),
		color,
		2.0
	)
	overlay.draw_line(
		global_pos - Vector2(0, cross_size),
		global_pos + Vector2(0, cross_size),
		color,
		2.0
	)
	overlay.draw_circle(global_pos, HANDLE_RADIUS_SPAWN, color)
	overlay.draw_circle(global_pos, HANDLE_RADIUS_SPAWN * 0.7, Color.BLACK)

func _draw_route_overlay(overlay: Control, r: RouteResource) -> void:
	if r == null:
		return
	var wps := r.waypoints
	var count := wps.size()
	if count == 0:
		return
	for i in range(count - 1):
		var p1 := _world_to_screen(_get_wp_global_pos(wps[i]))
		var p2 := _world_to_screen(_get_wp_global_pos(wps[i + 1]))
		var color := Color.CYAN
		if wps[i].level_id != wps[i + 1].level_id:
			color = Color.MAGENTA
		var width := 2.0
		if _edit_enabled and i == _route_hovered_segment_index:
			color = Color.YELLOW
			width = 4.0
		overlay.draw_line(p1, p2, color, width)

	for i2 in range(count):
		var p := _world_to_screen(_get_wp_global_pos(wps[i2]))
		var colorp := Color.WHITE
		var radius := HANDLE_RADIUS_ROUTE
		if _edit_enabled and i2 == _route_hovered_point_index:
			colorp = Color.GREEN
			radius = HANDLE_RADIUS_ROUTE * 1.2
		if _edit_enabled and i2 == _route_dragged_point_index:
			colorp = Color.RED
		overlay.draw_circle(p, radius, colorp)
		overlay.draw_circle(p, radius * 0.8, Color.BLACK)
