@tool
extends DialogicIndexer

## Single entrypoint indexer for dialogic_additions.
## Dialogic discovers indexers at: extensions_folder/<AnySubfolder>/index.gd
## so we keep exactly one indexer here and list events across subfolders.

func _get_events() -> Array:
	return [
		# Agents
		"res://addons/dialogic_additions/Agents/event_move_to_anchor.gd",
		"res://addons/dialogic_additions/Agents/event_teleport_to_anchor.gd",
		"res://addons/dialogic_additions/Agents/event_agent_spawn.gd",
		"res://addons/dialogic_additions/Agents/event_restore_agents.gd",
		"res://addons/dialogic_additions/Agents/event_wait_for_moves.gd",

		# CutsceneHelpers
		"res://addons/dialogic_additions/CutsceneHelpers/event_start_cutscene.gd",

		# CutsceneLoading
		"res://addons/dialogic_additions/CutsceneLoading/event_blackout_begin.gd",
		"res://addons/dialogic_additions/CutsceneLoading/event_blackout_end.gd",
	]
