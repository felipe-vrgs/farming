@tool
extends EditorInspectorPlugin

var plugin_ref

func init(plugin: EditorPlugin) -> void:
	plugin_ref = plugin

func _can_handle(object: Object) -> bool:
	return object is RouteResource

func _parse_begin(object: Object) -> void:
	var route = object as RouteResource
	var ui = RouteInspectorUI.new()
	ui.init(plugin_ref, route)
	add_custom_control(ui)

class RouteInspectorUI extends VBoxContainer:
	var plugin_ref
	var current_route: RouteResource
	var edit_btn: CheckButton

	func init(plugin, route):
		plugin_ref = plugin
		current_route = route

	func _ready() -> void:
		var hbox = HBoxContainer.new()
		add_child(hbox)

		edit_btn = CheckButton.new()
		edit_btn.text = "Edit Route Points"
		# Check if the plugin is currently editing THIS route
		_update_checkbox()
		edit_btn.toggled.connect(_on_toggled)
		hbox.add_child(edit_btn)

		if plugin_ref.has_signal("edit_state_changed"):
			plugin_ref.edit_state_changed.connect(_update_checkbox)

		var instructions = Label.new()
		instructions.text = "L-Click: Add/Move\nR-Click: Delete\nClick segment to insert."
		instructions.modulate = Color(0.7, 0.7, 0.7)
		add_child(instructions)

	func _update_checkbox() -> void:
		if not edit_btn or not plugin_ref:
			return
		var is_editing = plugin_ref.edit_mode and plugin_ref.current_route == current_route
		if edit_btn.button_pressed != is_editing:
			edit_btn.set_pressed_no_signal(is_editing)

	func _on_toggled(pressed: bool) -> void:
		if plugin_ref:
			plugin_ref.set_edit_mode(pressed, current_route)
