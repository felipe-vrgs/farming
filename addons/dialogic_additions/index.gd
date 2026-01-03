@tool
extends DialogicIndexer

## Root indexer for dialogic_additions.
## Dialogic is patched to load `extensions_folder/index.gd` if present, so we can
## organize custom events into multiple subfolders without multiple indexers.

func _get_events() -> Array:
	return [
		# CutsceneActors
		"res://addons/dialogic_additions/CutsceneActors/event_move_to_anchor.gd",
		"res://addons/dialogic_additions/CutsceneActors/event_teleport_to_anchor.gd",
		"res://addons/dialogic_additions/CutsceneActors/event_npc_travel_spawn.gd",
		"res://addons/dialogic_additions/CutsceneActors/event_restore_actors.gd",
		"res://addons/dialogic_additions/CutsceneActors/event_wait_for_moves.gd",

		# CutsceneLevel
		"res://addons/dialogic_additions/CutsceneLevel/event_start_cutscene.gd",
		"res://addons/dialogic_additions/CutsceneLevel/event_change_level_continue.gd",

		# CutsceneLoading
		"res://addons/dialogic_additions/CutsceneLoading/event_blackout_begin.gd",
		"res://addons/dialogic_additions/CutsceneLoading/event_blackout_end.gd",
	]

