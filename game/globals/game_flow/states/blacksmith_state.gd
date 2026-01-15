extends GameState

## BLACKSMITH overlay state:
## - Pause SceneTree + TimeManager
## - Disable player input
## - Show Blacksmith UI screen

const _PAUSE_REASON_BLACKSMITH := &"blacksmith"


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	# Pause overlay should return to blacksmith on resume.
	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED
	# Close blacksmith on player-menu inputs.
	if check_player_menu_input(event):
		return GameStateNames.IN_GAME

	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	if flow == null:
		return

	var node := _overlay_enter(
		_PAUSE_REASON_BLACKSMITH,
		UIManager.ScreenName.BLACKSMITH_MENU,
		[
			UIManager.ScreenName.PAUSE_MENU,
			UIManager.ScreenName.HUD,
			UIManager.ScreenName.PLAYER_MENU,
		]
	)
	var menu := node as BlacksmithMenu
	if menu != null:
		var p: Node = flow.get_player()
		var vendor_id: StringName = &""
		if Runtime != null:
			vendor_id = Runtime.get_blacksmith_vendor_id()
		var v: Node = Runtime.find_agent_by_id(vendor_id) if Runtime != null else null
		menu.setup(p, v)


func on_cover(_overlay: StringName) -> void:
	_overlay_cover(UIManager.ScreenName.BLACKSMITH_MENU)


func on_reveal(_overlay: StringName) -> void:
	_overlay_reassert(
		_PAUSE_REASON_BLACKSMITH,
		UIManager.ScreenName.BLACKSMITH_MENU,
		[
			UIManager.ScreenName.PAUSE_MENU,
			UIManager.ScreenName.HUD,
			UIManager.ScreenName.PLAYER_MENU,
		]
	)


func exit(_next: StringName = &"") -> void:
	_overlay_exit(_PAUSE_REASON_BLACKSMITH, UIManager.ScreenName.BLACKSMITH_MENU)
	if Runtime != null:
		Runtime.clear_blacksmith_vendor_id()
