extends GameState

var _return_state: StringName = GameStateNames.IN_GAME


func get_return_state() -> StringName:
	return _return_state


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE
	if event.is_action_pressed(&"pause"):
		return _return_state
	return GameStateNames.NONE


func enter(prev: StringName = &"") -> void:
	if flow == null:
		return

	# Return to the state we paused from (dialogue/cutscene/in_game).
	_return_state = prev if prev != GameStateNames.NONE else GameStateNames.IN_GAME
	if (
		_return_state != GameStateNames.IN_GAME
		and _return_state != GameStateNames.DIALOGUE
		and _return_state != GameStateNames.CUTSCENE
		and _return_state != GameStateNames.NIGHT
		and _return_state != GameStateNames.PLAYER_MENU
		and _return_state != GameStateNames.SHOPPING
		and _return_state != GameStateNames.BLACKSMITH
		and _return_state != GameStateNames.GRANT_REWARD
	):
		_return_state = GameStateNames.IN_GAME

	# Pause all gameplay.
	_overlay_enter(
		&"pause_menu",
		UIManager.ScreenName.PAUSE_MENU,
		[UIManager.ScreenName.PLAYER_MENU, UIManager.ScreenName.HUD]
	)
	if SFXManager != null:
		SFXManager.pause_music()

	# If we paused during dialogue/cutscene, hide Dialogic's layout so the textbox
	# doesn't remain visible underneath the pause menu.
	if _return_state == GameStateNames.DIALOGUE or _return_state == GameStateNames.CUTSCENE:
		if DialogueManager != null:
			DialogueManager.set_layout_visible(false)


func exit(_next: StringName = &"") -> void:
	# Resume gameplay.
	_overlay_exit(&"pause_menu", UIManager.ScreenName.PAUSE_MENU)
	if UIManager != null and _return_state == GameStateNames.IN_GAME:
		UIManager.show(UIManager.ScreenName.HUD)

	if SFXManager != null:
		SFXManager.resume_music()

	# If we're returning to dialogue/cutscene, re-show Dialogic layout.
	if _return_state == GameStateNames.DIALOGUE or _return_state == GameStateNames.CUTSCENE:
		if DialogueManager != null:
			DialogueManager.set_layout_visible(true)

	# Best-effort resume. Dialogue/Cutscene states override via their enter().
	if flow != null:
		flow.get_tree().paused = false
		GameplayUtils.set_player_input_enabled(flow.get_tree(), true)
		if _return_state == GameStateNames.IN_GAME:
			GameplayUtils.set_hotbar_visible(true)
