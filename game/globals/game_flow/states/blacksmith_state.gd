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

	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(_PAUSE_REASON_BLACKSMITH)

	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)

	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)
		UIManager.hide(UIManager.ScreenName.PLAYER_MENU)

		var node := UIManager.show(UIManager.ScreenName.BLACKSMITH_MENU)
		if node != null and node.has_method("setup"):
			var p: Node = flow.get_player()
			var vendor_id: StringName = &""
			if Runtime != null and Runtime.has_method("get_blacksmith_vendor_id"):
				vendor_id = Runtime.call("get_blacksmith_vendor_id")
			var v: Node = Runtime.find_agent_by_id(vendor_id) if Runtime != null else null
			node.call("setup", p, v)


func on_cover(_overlay: StringName) -> void:
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.BLACKSMITH_MENU)


func on_reveal(_overlay: StringName) -> void:
	if flow == null:
		return
	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(_PAUSE_REASON_BLACKSMITH)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)
	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)
		UIManager.hide(UIManager.ScreenName.PLAYER_MENU)
		UIManager.show(UIManager.ScreenName.BLACKSMITH_MENU)


func exit(_next: StringName = &"") -> void:
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.BLACKSMITH_MENU)
	if Runtime != null and Runtime.has_method("clear_blacksmith_vendor_id"):
		Runtime.call("clear_blacksmith_vendor_id")

	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_BLACKSMITH)

	if flow != null:
		GameplayUtils.set_player_input_enabled(flow.get_tree(), true)
