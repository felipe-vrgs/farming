extends GameState

## SHOPPING overlay state:
## - Pause SceneTree + TimeManager
## - Disable player input
## - Show Shop UI screen

const _PAUSE_REASON_SHOP := &"shop"


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	# Close shop.
	if event.is_action_pressed(&"pause") or check_player_menu_input(event):
		return GameStateNames.IN_GAME

	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	if flow == null:
		return

	# Pause gameplay but keep UI alive (UIManager and menu nodes run PROCESS_MODE_ALWAYS).
	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(_PAUSE_REASON_SHOP)

	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)

	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)
		UIManager.hide(UIManager.ScreenName.PLAYER_MENU)

		var node := UIManager.show(UIManager.ScreenName.SHOP_MENU)
		if node != null and node.has_method("setup"):
			var p: Node = flow.get_player()
			var vendor_id: StringName = &""
			if Runtime != null and Runtime.has_method("get_shop_vendor_id"):
				vendor_id = Runtime.call("get_shop_vendor_id")
			var v: Node = Runtime.find_agent_by_id(vendor_id) if Runtime != null else null
			node.call("setup", p, v)


func exit(_next: StringName = &"") -> void:
	# Hide overlay.
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.SHOP_MENU)
	if Runtime != null and Runtime.has_method("clear_shop_vendor_id"):
		Runtime.call("clear_shop_vendor_id")

	# Resume time (tree pause is controlled by the next state).
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_SHOP)

	# Best-effort re-enable input; the next state's enter() can override.
	if flow != null:
		GameplayUtils.set_player_input_enabled(flow.get_tree(), true)
