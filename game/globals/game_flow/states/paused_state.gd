extends GameState

var _return_state: StringName = GameStateNames.IN_GAME


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
		and _return_state != GameStateNames.PLAYER_MENU
	):
		_return_state = GameStateNames.IN_GAME

	# Pause all gameplay.
	if UIManager != null:
		UIManager.show(UIManager.ScreenName.HUD)
	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(&"pause_menu")

	# If we paused during dialogue/cutscene, hide Dialogic's layout so the textbox
	# doesn't remain visible underneath the pause menu.
	if _return_state == GameStateNames.DIALOGUE or _return_state == GameStateNames.CUTSCENE:
		if DialogueManager != null and DialogueManager.has_method("set_layout_visible"):
			DialogueManager.set_layout_visible(false)

	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)

	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.PLAYER_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)
		UIManager.show(UIManager.ScreenName.PAUSE_MENU)


func exit(_next: StringName = &"") -> void:
	# Resume gameplay.
	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.show(UIManager.ScreenName.HUD)

	if TimeManager != null:
		TimeManager.resume(&"pause_menu")

	# If we're returning to dialogue/cutscene, re-show Dialogic layout.
	if _return_state == GameStateNames.DIALOGUE or _return_state == GameStateNames.CUTSCENE:
		if DialogueManager != null and DialogueManager.has_method("set_layout_visible"):
			DialogueManager.set_layout_visible(true)

	# Best-effort resume. Dialogue/Cutscene states override via their enter().
	if flow != null:
		flow.get_tree().paused = false
		GameplayUtils.set_player_input_enabled(flow.get_tree(), true)
		GameplayUtils.set_hotbar_visible(true)
