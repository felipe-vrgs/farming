@tool
extends EditorInspectorPlugin

var plugin_ref

func init(plugin: EditorPlugin) -> void:
	plugin_ref = plugin

func _can_handle(object: Object) -> bool:
	return object is SpawnPointData or object is RouteResource

func _parse_begin(object: Object) -> void:
	var ui := LocalizerInspectorUI.new()
	ui.init(plugin_ref, object)
	add_custom_control(ui)


class LocalizerInspectorUI extends VBoxContainer:
	var plugin_ref
	var obj: Object
	var edit_btn: CheckButton
	var info: Label

	func init(plugin, object):
		plugin_ref = plugin
		obj = object

	func _ready() -> void:
		var header := HBoxContainer.new()
		add_child(header)

		edit_btn = CheckButton.new()
		edit_btn.text = "Edit" if obj is RouteResource else "Edit Position"
		_update_checkbox()
		edit_btn.toggled.connect(_on_toggled)
		header.add_child(edit_btn)

		var instructions := Label.new()
		instructions.modulate = Color(0.7, 0.7, 0.7)
		if obj is RouteResource:
			instructions.text = "L-Click: Add/Move\nR-Click: Delete\nClick segment to insert."
		else:
			instructions.text = "Click to set position.\nDrag handle to move."
		add_child(instructions)

		info = Label.new()
		_refresh_info()
		add_child(info)

		if plugin_ref != null and plugin_ref.has_signal("edit_state_changed"):
			plugin_ref.edit_state_changed.connect(_update_checkbox)
			plugin_ref.edit_state_changed.connect(_refresh_info)

	func _get_level_path(level_id: int) -> String:
		match level_id:
			Enums.Levels.ISLAND:
				return "res://game/levels/island.tscn"
			Enums.Levels.FRIEREN_HOUSE:
				return "res://game/levels/frieren_house.tscn"
			Enums.Levels.PLAYER_HOUSE:
				return "res://game/levels/player_house.tscn"
		return ""

	func _refresh_info() -> void:
		if info == null or obj == null:
			return

		var level_id := Enums.Levels.NONE
		if "level_id" in obj:
			level_id = obj.level_id
		var path := _get_level_path(int(level_id))

		if obj is SpawnPointData:
			var sp := obj as SpawnPointData
			info.text = "Type: SpawnPoint\nName: %s\nScene: %s\nPos: (%d, %d)" % [
				sp.display_name,
				path if path != "" else "<unknown>",
				int(sp.position.x),
				int(sp.position.y),
			]
			return

		if obj is RouteResource:
			var r := obj as RouteResource
			info.text = "Type: Route\nName: %s\nWaypoints: %d" % [
				String(r.route_name),
				int(r.waypoints.size()),
			]

	func _update_checkbox() -> void:
		if not edit_btn or not plugin_ref:
			return
		var is_editing := false
		if plugin_ref.has_method("is_editing") and obj != null:
			is_editing = bool(plugin_ref.call("is_editing", obj))
		if edit_btn.button_pressed != is_editing:
			edit_btn.set_pressed_no_signal(is_editing)

	func _on_toggled(pressed: bool) -> void:
		if plugin_ref != null and plugin_ref.has_method("set_edit_mode_for"):
			plugin_ref.call("set_edit_mode_for", pressed, obj)
