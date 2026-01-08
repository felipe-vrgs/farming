@tool
extends DialogicEvent

## Start a quest by id (handled by QuestManager).

var quest_id: String = ""


func _execute() -> void:
	if String(quest_id).is_empty():
		push_warning("Quest Start: quest_id is empty.")
		finish()
		return
	if QuestManager == null or not QuestManager.has_method("start_new_quest"):
		push_warning("Quest Start: QuestManager not available.")
		finish()
		return
	QuestManager.start_new_quest(StringName(quest_id))
	finish()


func _init() -> void:
	event_name = "Start Quest"
	set_default_color("Color7")
	event_category = "Quest"
	event_sorting_index = 0


func get_shortcode() -> String:
	return "quest_start"


func get_shortcode_parameters() -> Dictionary:
	return {
		"quest": {"property": "quest_id", "default": ""},
	}


func build_event_editor() -> void:
	add_header_label("Start quest")
	add_header_edit(
		"quest_id",
		ValueType.SINGLELINE_TEXT,
		{
			"placeholder": "quest_id (e.g. frieren_intro)",
		}
	)
