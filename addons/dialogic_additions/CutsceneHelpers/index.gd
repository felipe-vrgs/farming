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
		"res://addons/dialogic_additions/Agents/event_agent_face_pos.gd",
		"res://addons/dialogic_additions/Agents/event_agent_spawn.gd",
		"res://addons/dialogic_additions/Agents/event_restore_agents.gd",
		"res://addons/dialogic_additions/Agents/event_wait_for_moves.gd",

		# Camera
		"res://addons/dialogic_additions/Camera/event_camera_control.gd",

		# CutsceneHelpers
		"res://addons/dialogic_additions/CutsceneHelpers/event_start_cutscene.gd",

		# CutsceneLoading
		"res://addons/dialogic_additions/CutsceneLoading/event_blackout_begin.gd",
		"res://addons/dialogic_additions/CutsceneLoading/event_blackout_end.gd",

		# Emotes
		"res://addons/dialogic_additions/Emotes/event_emote_show.gd",

		# Portraits
		"res://addons/dialogic_additions/Portraits/event_portrait_effect.gd",

		# Quest
		"res://addons/dialogic_additions/Quest/event_quest_start.gd",
		"res://addons/dialogic_additions/Quest/event_quest_advance.gd",
	]
