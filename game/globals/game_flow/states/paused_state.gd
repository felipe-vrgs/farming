extends GameState


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE
	if event.is_action_pressed(&"pause"):
		return GameStateNames.IN_GAME
	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	if flow == null:
		return

	# Pause all gameplay.
	if UIManager != null:
		UIManager.show(UIManager.ScreenName.HUD)
	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(&"pause_menu")

	var p = flow.get_player()
	if p != null and p.has_method("set_input_enabled"):
		p.call("set_input_enabled", false)

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

	# Best-effort resume. Dialogue/Cutscene states override via their enter().
	if flow != null:
		flow.get_tree().paused = false
		flow.set_player_input_enabled(true)
		flow.set_hotbar_visible(true)
