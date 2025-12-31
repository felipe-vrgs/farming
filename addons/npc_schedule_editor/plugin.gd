@tool
extends EditorPlugin

var _inspector_plugin: EditorInspectorPlugin

func _enter_tree() -> void:
	_inspector_plugin = preload("res://addons/npc_schedule_editor/schedule_inspector.gd").new()
	# Pass editor dependencies (EditorInspectorPlugin doesn't expose get_editor_interface()).
	if _inspector_plugin.has_method("init"):
		_inspector_plugin.call("init", get_editor_interface(), get_undo_redo())
	add_inspector_plugin(_inspector_plugin)

func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
	_inspector_plugin = null

