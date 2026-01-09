@tool
extends VBoxContainer

const ScheduleDockScene := preload("res://addons/schedule_editor_dock/schedule_dock.tscn")
const WorldMapTabScene := preload("res://addons/schedule_editor_dock/world_map_tab.tscn")

var plugin_reference: EditorPlugin = null

var _editor_interface: EditorInterface = null
var _undo: EditorUndoRedoManager = null

var _tabs: TabContainer = null
var _schedule_dock: Control = null
var _world_map_tab: Control = null


func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface
	if _schedule_dock != null and _schedule_dock.has_method("set_editor_interface"):
		_schedule_dock.call("set_editor_interface", _editor_interface)
	if _world_map_tab != null and _world_map_tab.has_method("set_editor_interface"):
		_world_map_tab.call("set_editor_interface", _editor_interface)


func set_undo_redo(undo: EditorUndoRedoManager) -> void:
	_undo = undo
	if _schedule_dock != null and _schedule_dock.has_method("set_undo_redo"):
		_schedule_dock.call("set_undo_redo", _undo)
	if _world_map_tab != null and _world_map_tab.has_method("set_undo_redo"):
		_world_map_tab.call("set_undo_redo", _undo)


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)

	_schedule_dock = ScheduleDockScene.instantiate()
	_schedule_dock.name = "Schedules"
	_tabs.add_child(_schedule_dock)

	_world_map_tab = WorldMapTabScene.instantiate()
	_world_map_tab.name = "World Map"
	if plugin_reference != null and _world_map_tab.has_method("set_plugin_reference"):
		_world_map_tab.call("set_plugin_reference", plugin_reference)
	_tabs.add_child(_world_map_tab)

	if _editor_interface != null:
		set_editor_interface(_editor_interface)
	if _undo != null:
		set_undo_redo(_undo)


func edit_resource(object: Object) -> void:
	if object == null or _tabs == null:
		return

	if object is NpcConfig or object is NpcSchedule:
		if _schedule_dock != null and _schedule_dock.has_method("edit_resource"):
			_schedule_dock.call("edit_resource", object)
		_tabs.current_tab = 0
		return

	# Spawn points / routes go to World Map.
	if object is SpawnPointData or object is RouteResource:
		if _world_map_tab != null and _world_map_tab.has_method("select_resource"):
			_world_map_tab.call("select_resource", object)
		_tabs.current_tab = 1
		return
