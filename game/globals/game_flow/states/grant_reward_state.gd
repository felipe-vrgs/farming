extends GameState

## GRANT_REWARD state
## - Temporarily pauses the game and shows a reward presentation UI
## - Returns to the state that requested the reward flow

const _REWARD_POPUP_SCREEN := 9  # UIManager.ScreenName.REWARD_POPUP

var _return_state: StringName = GameStateNames.IN_GAME


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	# Close on confirm/cancel style inputs.
	if (
		event.is_action_pressed(&"ui_accept")
		or event.is_action_pressed(&"ui_cancel")
		or event.is_action_pressed(&"pause")
		or event.is_action_pressed(&"open_player_menu")
	):
		return _return_state

	return GameStateNames.NONE


func enter(prev: StringName = &"") -> void:
	if flow == null:
		return

	# Freeze gameplay but keep GameFlow running so it can receive input to close.
	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(&"grant_reward")

	GameplayUtils.set_hotbar_visible(false)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), false)

	# Determine where to return after closing.
	if flow.has_method("consume_grant_reward_return_state"):
		_return_state = StringName(flow.call("consume_grant_reward_return_state"))
	else:
		_return_state = prev
	if String(_return_state).is_empty():
		_return_state = GameStateNames.IN_GAME

	# Hide other UI and show the reward popup.
	var rows = flow.consume_grant_reward_rows()

	if UIManager != null:
		UIManager.hide_all_menus()
		var node := UIManager.show_screen(_REWARD_POPUP_SCREEN)
		if node != null:
			node.show_rewards("Rewards", rows)


func exit(_next: StringName = &"") -> void:
	# Restore time (tree pause is controlled by the next state).
	if TimeManager != null:
		TimeManager.resume(&"grant_reward")

	if UIManager != null and UIManager.has_method("hide"):
		var node := UIManager.get_screen_node(_REWARD_POPUP_SCREEN as UIManager.ScreenName)
		if node != null and node.has_method("hide_popup"):
			node.call("hide_popup")
		UIManager.hide_screen(_REWARD_POPUP_SCREEN)
