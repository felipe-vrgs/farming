@tool
extends DialogicEvent

## End a blackout transaction (fade back in and release the overlay).
## Nested calls are supported; only the last call performs the fade-in.
var time: float = 0.25

func _execute() -> void:
	if dialogic == null:
		finish()
		return
	if UIManager == null or not UIManager.has_method("blackout_end"):
		push_warning("BlackoutEnd: UIManager loading screen not available.")
		finish()
		return

	# Keep Dialogic layout hidden during fade-in so it can't appear briefly at the end of a cutscene
	# (common when blackout_end is followed immediately by [end_timeline]).
	if DialogueManager != null and DialogueManager.has_method("set_layout_visible"):
		DialogueManager.set_layout_visible(false)

	dialogic.current_state = dialogic.States.WAITING
	await UIManager.blackout_end(maxf(0.0, time))
	dialogic.current_state = dialogic.States.IDLE

	# Defer re-showing by 1 frame: if the timeline ends right after blackout_end,
	# DialogueManager will free the layout and this avoids a visible "flash".
	if dialogic != null:
		await dialogic.get_tree().process_frame
	if DialogueManager != null and DialogueManager.has_method("set_layout_visible"):
		DialogueManager.set_layout_visible(true)
	finish()

func _init() -> void:
	event_name = "Blackout End"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 11

func get_shortcode() -> String:
	return "cutscene_blackout_end"

func get_shortcode_parameters() -> Dictionary:
	return {
		"time": {"property": "time", "default": 0.25},
	}

func build_event_editor() -> void:
	add_header_label("Blackout end")
	add_header_edit("time", ValueType.NUMBER, {"left_text":"Fade in (s):", "min":0.0})
