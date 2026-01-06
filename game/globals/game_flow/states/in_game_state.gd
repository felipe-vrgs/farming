extends GameState


func enter(_prev: StringName = &"") -> void:
	# RUNNING gameplay state (single-state machine).
	if flow == null:
		return

	flow.force_unpaused()

	if UIManager != null:
		UIManager.hide_all_menus()
		UIManager.show(UIManager.ScreenName.HUD)

	GameplayUtils.set_player_input_enabled(flow.get_tree(), true)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), true)
	GameplayUtils.set_hotbar_visible(true)
	GameplayUtils.fade_vignette_out(0.15)


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	# Player menu toggle: only while actively playing.
	if event.is_action_pressed(&"open_player_menu"):
		if flow.get_player() != null:
			return GameStateNames.PLAYER_MENU

	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED

	return GameStateNames.NONE
