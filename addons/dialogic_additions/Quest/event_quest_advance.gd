@tool
extends DialogicEvent

## Advance a quest by a number of steps (handled by QuestManager).

var quest_id: String = ""
var steps: int = 1


func _execute() -> void:
	if String(quest_id).is_empty():
		push_warning("Quest Advance: quest_id is empty.")
		finish()
		return
	if QuestManager == null or not QuestManager.has_method("advance_quest"):
		push_warning("Quest Advance: QuestManager not available.")
		finish()
		return
	QuestManager.advance_quest(StringName(quest_id), int(steps))
	finish()


func _init() -> void:
	event_name = "Advance Quest"
	set_default_color("Color7")
	event_category = "Quest"
	event_sorting_index = 1


func get_shortcode() -> String:
	return "quest_advance"


func get_shortcode_parameters() -> Dictionary:
	return {
		"quest": {"property": "quest_id", "default": ""},
		"steps": {"property": "steps", "default": 1},
	}


func build_event_editor() -> void:
	add_header_label("Advance quest")
	add_header_edit(
		"quest_id",
		ValueType.SINGLELINE_TEXT,
		{
			"placeholder": "quest_id (e.g. frieren_intro)",
		}
	)
	add_header_edit(
		"steps",
		ValueType.NUMBER,
		{
			"placeholder": "steps (default 1)",
		}
	)
