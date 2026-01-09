extends GameState


func handle_unhandled_input(event: InputEvent) -> StringName:
	var rs := GameStateNames.NONE
	if flow == null or event == null:
		return rs

	# While PLAYER_MENU is open, these actions should *toggle/close* rather than re-request
	# opening the menu (which would be a no-op and would swallow the input).
	if event.is_action_pressed(&"open_player_menu"):
		rs = GameStateNames.IN_GAME
	if event.is_action_pressed(&"open_player_menu_inventory"):
		rs = _handle_tab_action(PlayerMenu.Tab.INVENTORY)
	if event.is_action_pressed(&"open_player_menu_quests"):
		rs = _handle_tab_action(PlayerMenu.Tab.QUESTS)
	if event.is_action_pressed(&"open_player_menu_relationships"):
		rs = _handle_tab_action(PlayerMenu.Tab.RELATIONSHIPS)
	if event.is_action_pressed(&"pause"):
		rs = GameStateNames.PAUSED

	return rs


func _handle_tab_action(tab: int) -> StringName:
	var pm: PlayerMenu = null
	if UIManager != null and UIManager.has_method("get_screen_node"):
		pm = UIManager.get_screen_node(UIManager.ScreenName.PLAYER_MENU) as PlayerMenu
	if pm == null:
		return GameStateNames.NONE
	if pm.get_current_tab() == int(tab):
		return GameStateNames.IN_GAME
	pm.open_tab(tab)
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
		var node := UIManager.show(UIManager.ScreenName.PLAYER_MENU)
		var menu := node as PlayerMenu
		if menu != null:
			menu.open_tab(flow.consume_player_menu_requested_tab())


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
