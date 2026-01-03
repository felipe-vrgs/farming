@tool
extends DialogicIndexer

func _get_events() -> Array:
	return [
		this_folder.path_join("event_move_to_anchor.gd"),
		this_folder.path_join("event_teleport_to_anchor.gd"),
		this_folder.path_join("event_change_level_continue.gd"),
	]

