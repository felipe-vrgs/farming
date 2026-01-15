@tool
extends DialogicEvent

## Apply a brief portrait effect to the active dialogue layout.
var effect: String = "wiggle"
var duration: float = 0.25
var intensity: float = 1.0
var wait_for_finish: bool = true


func _execute() -> void:
	if DialogueManager == null:
		finish()
		return
	DialogueManager.play_portrait_effect(effect, duration, intensity)

	if wait_for_finish and duration > 0.0:
		if dialogic != null:
			dialogic.current_state = dialogic.States.WAITING
		if dialogic != null:
			await dialogic.get_tree().create_timer(maxf(0.0, duration)).timeout
		if dialogic != null:
			dialogic.current_state = dialogic.States.IDLE

	finish()


func _init() -> void:
	event_name = "Portrait Effect"
	set_default_color("Color7")
	event_category = "Dialogue"
	event_sorting_index = 12


func get_shortcode() -> String:
	return "portrait_effect"


func get_shortcode_parameters() -> Dictionary:
	return {
		"effect": {"property": "effect", "default": "wiggle"},
		"duration": {"property": "duration", "default": 0.25},
		"intensity": {"property": "intensity", "default": 1.0},
		"wait": {"property": "wait_for_finish", "default": true},
	}


func build_event_editor() -> void:
	add_header_label("Portrait effect")
	add_header_edit("effect", ValueType.FIXED_OPTIONS, {
		"left_text": "Effect:",
		"options": [
			"wiggle",
			"bob",
			"shake",
			"nudge_up",
			"nudge_down",
			"nudge_left",
			"nudge_right",
			"pulse",
			"reset",
		],
	})

	add_body_edit("duration", ValueType.NUMBER, {"left_text": "Duration (s):", "min": 0.0})
	add_body_edit("intensity", ValueType.NUMBER, {"left_text": "Intensity:", "min": 0.0})
	add_body_edit("wait_for_finish", ValueType.BOOL, {"left_text": "Wait for finish:"})
