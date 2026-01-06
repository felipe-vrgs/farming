extends GameState


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	if event.is_action_pressed(&"open_player_menu"):
		return GameStateNames.IN_GAME

	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED

	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	if flow == null:
		return

	# Pause gameplay but keep UI alive (UIManager and menu nodes run PROCESS_MODE_ALWAYS).
	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(&"player_menu")

	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)

	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)
		UIManager.show(UIManager.ScreenName.PLAYER_MENU)


func exit(_next: StringName = &"") -> void:
	# Hide overlay.
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.PLAYER_MENU)

	# Resume time (tree pause is controlled by the next state).
	if TimeManager != null:
		TimeManager.resume(&"player_menu")

	# Best-effort re-enable input; the next state's enter() can override.
	if flow != null:
		GameplayUtils.set_player_input_enabled(flow.get_tree(), true)
