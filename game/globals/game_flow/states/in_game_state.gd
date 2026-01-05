extends "res://game/globals/game_flow/states/game_flow_state.gd"

const STATE_PAUSED := 4
const STATE_PLAYER_MENU := 5


func enter(_prev: int) -> void:
	if flow != null and flow.has_method("_enter_in_game"):
		flow.call("_enter_in_game")


func handle_unhandled_input(event: InputEvent) -> bool:
	if flow == null or event == null:
		return false

	# Player menu toggle: only while actively playing.
	if event.is_action_pressed(&"open_player_menu"):
		if flow.has_method("_get_player") and flow.call("_get_player") != null:
			flow.call("_set_state", STATE_PLAYER_MENU)
			return true

	if event.is_action_pressed(&"pause"):
		flow.call("_set_state", STATE_PAUSED)
		return true

	return false
