@tool
extends EditorInspectorPlugin

var plugin_ref

func init(plugin: EditorPlugin) -> void:
	plugin_ref = plugin

func _can_handle(object: Object) -> bool:
	return object is SpawnPointData

func _parse_begin(object: Object) -> void:
	var spawn_point = object as SpawnPointData
	var ui = SpawnPointInspectorUI.new()
	ui.init(plugin_ref, spawn_point)
	add_custom_control(ui)


class SpawnPointInspectorUI extends VBoxContainer:
	var plugin_ref
	var current_spawn_point: SpawnPointData
	var edit_btn: CheckButton

	func init(plugin, spawn_point):
		plugin_ref = plugin
		current_spawn_point = spawn_point

	func _ready() -> void:
		var header = HBoxContainer.new()
		add_child(header)

		edit_btn = CheckButton.new()
		edit_btn.text = "Edit Position"
		_update_checkbox()
		edit_btn.toggled.connect(_on_toggled)
		header.add_child(edit_btn)

		if plugin_ref.has_signal("edit_state_changed"):
			plugin_ref.edit_state_changed.connect(_update_checkbox)

		var instructions = Label.new()
		instructions.text = "Click to set position.\nDrag handle to move."
		instructions.modulate = Color(0.7, 0.7, 0.7)
		add_child(instructions)

		# Show current info
		var info = Label.new()
		info.text = "Level: %s\nPosition: (%d, %d)" % [
			_get_level_name(current_spawn_point.level_id),
			int(current_spawn_point.position.x),
			int(current_spawn_point.position.y)
		]
		add_child(info)

	func _get_level_name(level_id: int) -> String:
		match level_id:
			Enums.Levels.NONE:
				return "NONE"
			Enums.Levels.ISLAND:
				return "ISLAND"
			Enums.Levels.FRIEREN_HOUSE:
				return "FRIEREN_HOUSE"
		return "Unknown"

	func _update_checkbox() -> void:
		if not edit_btn or not plugin_ref:
			return
		var is_editing = plugin_ref.edit_mode and plugin_ref.current_spawn_point == current_spawn_point
		if edit_btn.button_pressed != is_editing:
			edit_btn.set_pressed_no_signal(is_editing)

	func _on_toggled(pressed: bool) -> void:
		if plugin_ref:
			plugin_ref.set_edit_mode(pressed, current_spawn_point)
