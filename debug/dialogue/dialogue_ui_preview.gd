extends Node

## Simple in-game preview for iterating on Dialogic UI.
## - Runs a sample timeline using the wood style.
## - Press R to restart + reapply style (good for tweaking resources).
## - Press Esc to quit.

const STYLE_PATH := "res://game/globals/dialogue/styles/text_box_wood.tres"
const TIMELINE_PATH := "res://game/globals/dialogue/timelines/npcs/frieren/greeting.dtl"

var _status_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_status_overlay()
	call_deferred("_start_preview")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_start_preview()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
			get_viewport().set_input_as_handled()


func _start_preview() -> void:
	_set_status("Starting preview…")
	await get_tree().process_frame

	var dialogic := get_node_or_null(NodePath("/root/Dialogic"))
	if dialogic == null or not is_instance_valid(dialogic):
		_set_status("Dialogic not found at /root/Dialogic")
		return

	if not ResourceLoader.exists(TIMELINE_PATH):
		_set_status("Timeline missing: %s" % TIMELINE_PATH)
		return

	if not ResourceLoader.exists(STYLE_PATH):
		_set_status("Style missing: %s" % STYLE_PATH)
		return

	# Force-reload the style resource so edits apply immediately.
	# Godot will still keep references cached unless we explicitly replace.
	ResourceLoader.load(STYLE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	# Ensure Dialogic picks up the latest style directory.
	DialogicStylesUtil.update_style_directory()

	# Best-effort stop any running timeline/layout.
	if dialogic.has_method("end_timeline"):
		dialogic.call("end_timeline")

	# Ensure style is active before starting.
	var styles = dialogic.get("Styles") if ("Styles" in dialogic) else null
	if styles != null and is_instance_valid(styles) and styles.has_method("load_style"):
		styles.call("load_style", STYLE_PATH)

	_set_status("Running. R=restart, Esc=quit")
	dialogic.call("start", TIMELINE_PATH)


func _ensure_status_overlay() -> void:
	if _status_label != null:
		return

	var layer := CanvasLayer.new()
	layer.layer = 999
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 1)
	root.add_child(bg)

	_status_label = Label.new()
	_status_label.position = Vector2(8, 8)
	_status_label.text = "Dialogue UI Preview"
	root.add_child(_status_label)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
