extends Node

## Simple in-game preview for iterating on Dialogic UI.
## - Runs a sample timeline using the wood style.
## - Press R to restart + reapply style (good for tweaking resources).
## - Press Esc to quit.

const STYLE_PATH := "res://game/globals/dialogue/styles/text_box_wood.tres"
const TIMELINE_PATH := "res://game/globals/dialogue/timelines/npcs/frieren/greeting.dtl"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_start_preview()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
			get_viewport().set_input_as_handled()


func _start_preview() -> void:
	if not _is_dialogic_ready():
		push_warning("DialogueUIPreview: Dialogic autoload not found.")
		return

	# Force-reload the style resource so edits apply immediately.
	# Godot will still keep references cached unless we explicitly replace.
	if ResourceLoader.exists(STYLE_PATH):
		ResourceLoader.load(STYLE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)

	# Best-effort stop any running timeline/layout.
	if Dialogic.has_method("end_timeline"):
		Dialogic.end_timeline()

	# Ensure style is active before starting.
	if (
		"Styles" in Dialogic
		and Dialogic.Styles != null
		and Dialogic.Styles.has_method("load_style")
	):
		Dialogic.Styles.load_style(STYLE_PATH)

	Dialogic.start(TIMELINE_PATH)


func _is_dialogic_ready() -> bool:
	return typeof(Dialogic) != TYPE_NIL and Dialogic != null
