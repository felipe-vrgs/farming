@tool
extends DialogicEvent

## Begin a blackout transaction (fade to black and keep it black).
## Nested calls are supported; only the first call performs the fade-out.
var time: float = 0.25

func _execute() -> void:
	if dialogic == null:
		finish()
		return
	if UIManager == null:
		push_warning("BlackoutBegin: UIManager loading screen not available.")
		finish()
		return

	# Hide Dialogic layout during blackout fades to avoid the textbox flashing above/below the overlay.
	if DialogueManager != null:
		DialogueManager.set_layout_visible(false)

	dialogic.current_state = dialogic.States.WAITING
	await UIManager.blackout_begin(maxf(0.0, time))
	dialogic.current_state = dialogic.States.IDLE

	finish()

func _init() -> void:
	event_name = "Blackout Begin"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 10

func get_shortcode() -> String:
	return "cutscene_blackout_begin"

func get_shortcode_parameters() -> Dictionary:
	return {
		"time": {"property": "time", "default": 0.25},
	}

func build_event_editor() -> void:
	add_header_label("Blackout begin")
	add_header_edit("time", ValueType.NUMBER, {"left_text":"Fade out (s):", "min":0.0})
