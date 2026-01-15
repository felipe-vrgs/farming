extends GameState

## SHOPPING overlay state:
## - Pause SceneTree + TimeManager
## - Disable player input
## - Show Shop UI screen

const _PAUSE_REASON_SHOP := &"shop"


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	# Pause overlay should return to shop on resume.
	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED
	# Close shop on player-menu inputs.
	if check_player_menu_input(event):
		return GameStateNames.IN_GAME

	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	if flow == null:
		return

	var node := _overlay_enter(
		_PAUSE_REASON_SHOP,
		UIManager.ScreenName.SHOP_MENU,
		[
			UIManager.ScreenName.PAUSE_MENU,
			UIManager.ScreenName.HUD,
			UIManager.ScreenName.PLAYER_MENU,
		]
	)
	var menu := node as ShopMenu
	if menu != null:
		var p: Node = flow.get_player()
		var vendor_id: StringName = &""
		if Runtime != null:
			vendor_id = Runtime.get_shop_vendor_id()
		var v: Node = Runtime.find_agent_by_id(vendor_id) if Runtime != null else null
		menu.setup(p, v)


func on_cover(_overlay: StringName) -> void:
	_overlay_cover(UIManager.ScreenName.SHOP_MENU)


func on_reveal(_overlay: StringName) -> void:
	_overlay_reassert(
		_PAUSE_REASON_SHOP,
		UIManager.ScreenName.SHOP_MENU,
		[
			UIManager.ScreenName.PAUSE_MENU,
			UIManager.ScreenName.HUD,
			UIManager.ScreenName.PLAYER_MENU,
		]
	)


func exit(_next: StringName = &"") -> void:
	_overlay_exit(_PAUSE_REASON_SHOP, UIManager.ScreenName.SHOP_MENU)
	if Runtime != null:
		Runtime.clear_shop_vendor_id()
