@tool
extends DialogicEvent

## Request a cutscene by id (handled by DialogueManager via EventBus).

var cutscene_id: String = ""

func _execute() -> void:
	if String(cutscene_id).is_empty():
		push_warning("Start: cutscene_id is empty.")
		finish()
		return
	if EventBus == null:
		push_warning("Start: EventBus not available.")
		finish()
		return
	EventBus.cutscene_start_requested.emit(cutscene_id, null)
	finish()

func _init() -> void:
	event_name = "Start Cutscene"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 0

func get_shortcode() -> String:
	return "cutscene_start"

func get_shortcode_parameters() -> Dictionary:
	return {
		"cutscene": {"property": "cutscene_id", "default": ""},
	}

func build_event_editor() -> void:
	add_header_label("Start cutscene")
	add_header_edit(
		"cutscene_id",
		ValueType.SINGLELINE_TEXT,
		{
			"placeholder": "cutscene_id (e.g. frieren_house_visit)",
		}
	)

