class_name DialogicFacade
extends Node

## Facade for the Dialogic library.
## Encapsulates all direct interactions with the Dialogic singleton.
## Handles low-level timeline operations, variable access, and signals.

signal timeline_ended(timeline_id: StringName)

const _PROD_TIMELINES_ROOT := "res://game/globals/dialogue/timelines/"
const _TEST_TIMELINES_ROOT := "res://tests/fixtures/dialogue/timelines/"
const _UI_THEME: Theme = preload("res://game/ui/theme/ui_theme.tres")
const _DIALOGUE_STYLE_PATH := "res://game/globals/dialogue/styles/text_box_wood.tres"

var _dialogic: Node = null
var _saved_dialogic_ending_timeline: Variant = null
var _suppress_dialogic_ending_timeline_depth: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic:
		_connect_dialogic_signals()


func is_dialogic_ready() -> bool:
	if _dialogic == null:
		_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	return _dialogic != null


func start_timeline(timeline_id: StringName) -> Node:
	if not is_dialogic_ready():
		push_warning("DialogicFacade: Dialogic not found.")
		return null

	var timeline_path := _resolve_timeline_path(timeline_id)
	if not ResourceLoader.exists(timeline_path):
		push_warning("DialogicFacade: Timeline not found: %s" % timeline_path)
		return null

	_dialogic.process_mode = Node.PROCESS_MODE_ALWAYS

	# Ensure our game UI style is active (prevents drift from editor/test styles).
	# Dialogic accepts either a style name or a resource path; we use the resource path.
	if "Styles" in _dialogic and _dialogic.get("Styles") != null:
		var styles: Node = _dialogic.get("Styles") as Node
		if styles != null and is_instance_valid(styles) and styles.has_method("load_style"):
			styles.call("load_style", _DIALOGUE_STYLE_PATH)

	if _dialogic.has_method("start"):
		var layout = _dialogic.call("start", timeline_path)
		_apply_layout_overrides(layout)
		return layout

	return null


func preload_timeline(timeline_id: StringName) -> void:
	if is_dialogic_ready() and _dialogic.has_method("preload_timeline"):
		_dialogic.call("preload_timeline", _resolve_timeline_path(timeline_id))


func end_timeline() -> void:
	if is_dialogic_ready() and _dialogic.has_method("end_timeline"):
		_dialogic.call("end_timeline")


func clear() -> void:
	if is_dialogic_ready() and _dialogic.has_method("clear"):
		_dialogic.call("clear")


func get_variables() -> Dictionary:
	if not is_dialogic_ready():
		return {}

	if "current_state_info" in _dialogic:
		var csi = _dialogic.get("current_state_info")
		if csi is Dictionary and csi.has("variables") and csi["variables"] is Dictionary:
			return csi["variables"]
	return {}


func set_variables(variables: Dictionary) -> void:
	if not is_dialogic_ready():
		return

	if "current_state_info" in _dialogic:
		var csi = _dialogic.get("current_state_info")
		if csi is Dictionary:
			csi["variables"] = variables.duplicate(true)


func set_completed_timeline(timeline_id: StringName) -> void:
	var vars = get_variables()
	if not vars.has("completed_timelines") or not (vars["completed_timelines"] is Dictionary):
		vars["completed_timelines"] = {}

	var segments := String(timeline_id).split("/", false)
	if segments.is_empty():
		return
	_set_nested_bool(vars["completed_timelines"] as Dictionary, segments, true)


func set_quest_active(quest_id: StringName, active: bool) -> void:
	if String(quest_id).is_empty():
		return
	var vars := get_variables()
	if vars.is_empty():
		return
	_set_nested_value(vars, ["quests", String(quest_id), "active"], active)


func set_quest_step(quest_id: StringName, step_index: int) -> void:
	if String(quest_id).is_empty():
		return
	var vars := get_variables()
	if vars.is_empty():
		return
	_set_nested_value(vars, ["quests", String(quest_id), "step"], int(step_index))


func set_quest_completed(quest_id: StringName, completed: bool) -> void:
	if String(quest_id).is_empty():
		return
	var vars := get_variables()
	if vars.is_empty():
		return
	_set_nested_value(vars, ["quests", String(quest_id), "completed"], completed)


func set_relationship_units(npc_id: StringName, units: int) -> void:
	if String(npc_id).is_empty():
		return
	var vars := get_variables()
	if vars.is_empty():
		return
	_set_nested_value(vars, ["relationships", String(npc_id), "units"], int(units))


func begin_fast_end() -> void:
	_suppress_dialogic_ending_timeline_depth += 1
	if _suppress_dialogic_ending_timeline_depth != 1:
		return
	if not is_dialogic_ready():
		return

	if _saved_dialogic_ending_timeline == null and "dialog_ending_timeline" in _dialogic:
		_saved_dialogic_ending_timeline = _dialogic.get("dialog_ending_timeline")

	if "dialog_ending_timeline" in _dialogic:
		_dialogic.set("dialog_ending_timeline", null)


func end_fast_end() -> void:
	_suppress_dialogic_ending_timeline_depth = max(0, _suppress_dialogic_ending_timeline_depth - 1)
	if _suppress_dialogic_ending_timeline_depth != 0:
		return
	if not is_dialogic_ready():
		return

	if _saved_dialogic_ending_timeline != null and "dialog_ending_timeline" in _dialogic:
		_dialogic.set("dialog_ending_timeline", _saved_dialogic_ending_timeline)
	_saved_dialogic_ending_timeline = null


#region Internal
func _resolve_timeline_path(timeline_id: StringName) -> String:
	var root := _PROD_TIMELINES_ROOT
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		# Keep shipping content clean: headless tests load fixtures from tests/.
		root = _TEST_TIMELINES_ROOT
	return root + String(timeline_id) + ".dtl"


func _connect_dialogic_signals() -> void:
	var end_signal_names := [
		"timeline_ended",
		"timeline_finished",
		"dialogue_ended",
		"finished",
	]
	for s in end_signal_names:
		if _dialogic.has_signal(s) and not _dialogic.is_connected(s, _on_dialogue_finished):
			_dialogic.connect(s, _on_dialogue_finished)


func _on_dialogue_finished(_a = null, _b = null, _c = null) -> void:
	timeline_ended.emit(&"")


func _apply_layout_overrides(layout: Node) -> void:
	if layout == null or not is_instance_valid(layout):
		return
	layout.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_ui_theme_best_effort(layout)


func _apply_ui_theme_best_effort(root: Node) -> void:
	# Dialogic layouts are often CanvasLayers; apply the project UI theme to any
	# Control nodes inside the returned layout so they inherit fonts/colors.
	if root == null or not is_instance_valid(root):
		return

	if root is Control:
		var c := root as Control
		# Avoid clobbering any explicitly-set theme on a layer.
		if c.theme == null:
			c.theme = _UI_THEME

	for child: Node in root.get_children():
		_apply_ui_theme_best_effort(child)


func _set_nested_bool(root: Dictionary, segments: Array[String], value: bool) -> void:
	if root == null or segments.is_empty():
		return
	var d := root
	for i in range(segments.size()):
		var k := segments[i]
		if k.is_empty():
			continue
		var is_last := i == segments.size() - 1
		if is_last:
			d[k] = value
			return
		if not d.has(k) or not (d[k] is Dictionary):
			d[k] = {}
		d = d[k] as Dictionary


func _set_nested_value(root: Dictionary, segments: Array[String], value: Variant) -> void:
	if root == null or segments.is_empty():
		return
	var d := root
	for i in range(segments.size()):
		var k := segments[i]
		if k.is_empty():
			continue
		var is_last := i == segments.size() - 1
		if is_last:
			d[k] = value
			return
		if not d.has(k) or not (d[k] is Dictionary):
			d[k] = {}
		d = d[k] as Dictionary
#endregion
