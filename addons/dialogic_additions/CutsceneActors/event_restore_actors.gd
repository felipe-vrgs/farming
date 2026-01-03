@tool
extends DialogicEvent

## Restore one or more actors to their pre-cutscene snapshot captured by DialogueManager.
## This is an explicit action; if the timeline doesn't call it, no auto-restore happens.
##
## Actor ids are provided as a comma-separated string (e.g. "player,frieren").

var actor_ids: String = "player"

func _execute() -> void:
	if DialogueManager == null or not DialogueManager.has_method("restore_cutscene_actor_snapshot"):
		push_warning("RestoreActors: DialogueManager restore API not available.")
		finish()
		return

	if actor_ids.strip_edges().is_empty():
		push_warning("RestoreActors: actor_ids is empty.")
		finish()
		return

	dialogic.current_state = dialogic.States.WAITING
	for raw in actor_ids.split(",", false):
		var t := raw.strip_edges()
		if t.is_empty():
			continue
		await DialogueManager.restore_cutscene_actor_snapshot(StringName(t))
	dialogic.current_state = dialogic.States.IDLE
	finish()

func _init() -> void:
	event_name = "Restore Actors"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 5

func get_shortcode() -> String:
	# Keep shortcode stable for existing timelines.
	return "cutscene_restore_actors"

func get_shortcode_parameters() -> Dictionary:
	return {
		"actor_id": {"property": "actor_ids", "default": "player"},
	}

func build_event_editor() -> void:
	add_header_label("Restore actors")
	add_header_edit(
		"actor_ids",
		ValueType.SINGLELINE_TEXT,
		{"placeholder":"Comma-separated ids (player,frieren,...)"}
	)

