@tool
extends EditorPlugin

var dock

func _enter_tree():
	dock = preload("res://addons/save_inspector/save_dock.tscn").instantiate()
	if dock.has_method("set_editor_interface"):
		dock.set_editor_interface(get_editor_interface())
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
