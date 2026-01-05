extends "res://game/globals/game_flow/states/game_flow_state.gd"

const STATE_IN_GAME := 3
const STATE_PAUSED := 4


func enter(_prev: int) -> void:
	if flow != null and flow.has_method("_enter_player_menu"):
		flow.call("_enter_player_menu")


func exit(_next: int) -> void:
	if flow != null and flow.has_method("_exit_player_menu"):
		flow.call("_exit_player_menu")


func handle_unhandled_input(event: InputEvent) -> bool:
	if flow == null or event == null:
		return false

	if event.is_action_pressed(&"open_player_menu"):
		flow.call("_set_state", STATE_IN_GAME)
		return true

	if event.is_action_pressed(&"pause"):
		flow.call("_set_state", STATE_PAUSED)
		return true

	return false
