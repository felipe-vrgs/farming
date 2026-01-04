@tool
extends EditorPlugin

signal edit_state_changed

const HANDLE_RADIUS = 10.0
const SpawnPointInspectorPlugin = preload(
	"res://addons/spawn_point_editor/spawn_point_inspector.gd"
)

var inspector_plugin
var current_spawn_point: SpawnPointData
var edit_mode: bool = false
var is_dragging: bool = false
var drag_start_pos: Vector2

func _enter_tree() -> void:
	inspector_plugin = SpawnPointInspectorPlugin.new()
	inspector_plugin.init(self)
	add_inspector_plugin(inspector_plugin)

func _exit_tree() -> void:
	remove_inspector_plugin(inspector_plugin)
	if inspector_plugin:
		inspector_plugin = null

func _handles(object: Object) -> bool:
	if object is SpawnPointData:
		return true

	if edit_mode and object is Node:
		if current_spawn_point:
			var scene_root = EditorInterface.get_edited_scene_root()
			if scene_root:
				var scene_path = scene_root.scene_file_path
				var spawn_level_path = _get_level_path(current_spawn_point.level_id)
				if spawn_level_path == "" or spawn_level_path == scene_path:
					return true
		else:
			return false

	return false

func _get_level_path(level_id: int) -> String:
	match level_id:
		Enums.Levels.ISLAND:
			return "res://game/levels/island.tscn"
		Enums.Levels.FRIEREN_HOUSE:
			return "res://game/levels/frieren_house.tscn"
	return ""

func _edit(object: Object) -> void:
	if object is SpawnPointData:
		current_spawn_point = object
		edit_state_changed.emit()
		update_overlays()
	elif object == null:
		update_overlays()

func set_edit_mode(enabled: bool, spawn_point: SpawnPointData) -> void:
	edit_mode = enabled
	current_spawn_point = spawn_point

	if enabled and current_spawn_point:
		_open_level_for_spawn_point(current_spawn_point)

	edit_state_changed.emit()
	update_overlays()

func _open_level_for_spawn_point(spawn_point: SpawnPointData) -> void:
	if spawn_point.level_id == Enums.Levels.NONE:
		return

	var level_name = ""
	match spawn_point.level_id:
		Enums.Levels.ISLAND:
			level_name = "island"
		Enums.Levels.FRIEREN_HOUSE:
			level_name = "frieren_house"

	if level_name != "":
		var path = "res://game/levels/%s.tscn" % level_name
		if FileAccess.file_exists(path):
			var current = EditorInterface.get_edited_scene_root()
			if current and current.scene_file_path == path:
				return

			EditorInterface.open_scene_from_path(path)
			print("Switched to scene: ", path)
			call_deferred("_restore_spawn_point_selection", spawn_point)

func _restore_spawn_point_selection(spawn_point: SpawnPointData) -> void:
	var selection = EditorInterface.get_selection()
	selection.clear()
	EditorInterface.edit_resource(spawn_point)

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not edit_mode or not current_spawn_point:
		return false

	if event is InputEventMouseButton:
		return _handle_mouse_click(event as InputEventMouseButton)

	if event is InputEventMouseMotion:
		if is_dragging:
			var mouse_pos = _get_mouse_position_world(event.position)
			current_spawn_point.position = _snap_to_grid(mouse_pos)
			update_overlays()
			return true

	return false

func _handle_mouse_click(mb: InputEventMouseButton) -> bool:
	var mouse_pos = _get_mouse_position_world(mb.position)

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# Check if clicking on handle
			var handle_pos = current_spawn_point.position
			var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
			var screen_handle = viewport_trans * handle_pos
			var screen_click = viewport_trans * mouse_pos

			if screen_handle.distance_to(screen_click) < HANDLE_RADIUS + 4.0:
				is_dragging = true
				drag_start_pos = handle_pos
				return true

			# Click elsewhere to set position
			_set_position(_snap_to_grid(mouse_pos))
			return true

		# Mouse release
		if is_dragging:
			_end_drag()
			is_dragging = false
			return true

	return false

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not edit_mode or not current_spawn_point:
		return

	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var pos = current_spawn_point.position
	var screen_pos = viewport_trans * pos

	# Draw crosshair
	var cross_size = 20.0
	var color = Color.LIME if not is_dragging else Color.RED
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

	# Draw handle circle
	overlay.draw_circle(screen_pos, HANDLE_RADIUS, color)
	overlay.draw_circle(screen_pos, HANDLE_RADIUS * 0.7, Color.BLACK)

	# Draw label
	var label = "Spawn Point"
	if current_spawn_point.display_name != "":
		label = current_spawn_point.display_name
	overlay.draw_string(
		ThemeDB.get_fallback_font(),
		screen_pos + Vector2(15, -15),
		"%s\n(%d, %d)" % [label, int(pos.x), int(pos.y)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color.WHITE
	)

func _get_mouse_position_world(screen_pos: Vector2) -> Vector2:
	var viewport_trans = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	return viewport_trans.affine_inverse() * screen_pos

func _snap_to_grid(pos: Vector2) -> Vector2:
	# Snap to 1 pixel for precision
	return Vector2(round(pos.x), round(pos.y))

func _set_position(pos: Vector2) -> void:
	var ur = get_undo_redo()
	ur.create_action("Set Spawn Point Position")
	ur.add_do_property(current_spawn_point, "position", pos)
	ur.add_undo_property(current_spawn_point, "position", current_spawn_point.position)
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()

func _end_drag() -> void:
	if drag_start_pos == current_spawn_point.position:
		return

	var ur = get_undo_redo()
	ur.create_action("Move Spawn Point")
	var final_pos = current_spawn_point.position
	ur.add_do_property(current_spawn_point, "position", final_pos)
	ur.add_undo_property(current_spawn_point, "position", drag_start_pos)
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()
