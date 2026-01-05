extends GameState


func enter(_prev: StringName = &"") -> void:
	# RUNNING gameplay state (single-state machine).
	if flow == null:
		return

	flow.force_unpaused()

	flow.hide_all_menus()
	if UIManager != null:
		UIManager.show(UIManager.ScreenName.HUD)

	flow.set_player_input_enabled(true)
	flow.set_npc_controllers_enabled(true)
	flow.set_hotbar_visible(true)
	flow.fade_vignette_out(0.15)


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
