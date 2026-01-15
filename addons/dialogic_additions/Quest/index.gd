@tool
extends DialogicIndexer

## Quest events for Dialogic additions.

func _get_events() -> Array:
	return [
		"res://addons/dialogic_additions/Quest/event_quest_start.gd",
		"res://addons/dialogic_additions/Quest/event_quest_advance.gd",
	]
