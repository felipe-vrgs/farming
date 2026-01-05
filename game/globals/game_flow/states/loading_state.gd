extends GameState


func enter(_prev: StringName = &"") -> void:
	# LOADING is primarily driven by GameFlow.run_loading_action/_run_loading and/or SceneLoader.
	# This state ensures we always enter loading with a consistent "locked" baseline.
	if flow == null:
		return
	flow.force_unpaused()
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), false)
	GameplayUtils.set_hotbar_visible(false)
