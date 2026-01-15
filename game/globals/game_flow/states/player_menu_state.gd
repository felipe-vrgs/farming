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
	if UIManager != null:
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

	var node := _overlay_enter(
		&"player_menu",
		UIManager.ScreenName.PLAYER_MENU,
		[UIManager.ScreenName.PAUSE_MENU, UIManager.ScreenName.HUD]
	)
	var menu := node as PlayerMenu
	if menu != null:
		menu.open_tab(flow.consume_player_menu_requested_tab())


func on_cover(_overlay: StringName) -> void:
	_overlay_cover(UIManager.ScreenName.PLAYER_MENU)


func on_reveal(_overlay: StringName) -> void:
	# Re-assert paused UI state without re-opening tabs.
	_overlay_reassert(
		&"player_menu",
		UIManager.ScreenName.PLAYER_MENU,
		[UIManager.ScreenName.PAUSE_MENU, UIManager.ScreenName.HUD]
	)


func exit(_next: StringName = &"") -> void:
	_overlay_exit(&"player_menu", UIManager.ScreenName.PLAYER_MENU)
