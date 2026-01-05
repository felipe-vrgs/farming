extends "res://game/globals/game_flow/states/game_flow_state.gd"

const STATE_IN_GAME := 3


func enter(_prev: int) -> void:
	if flow != null and flow.has_method("_enter_paused"):
		flow.call("_enter_paused")


func exit(_next: int) -> void:
	if flow != null and flow.has_method("_exit_paused"):
		flow.call("_exit_paused")


func handle_unhandled_input(event: InputEvent) -> bool:
	if flow == null or event == null:
		return false
	if event.is_action_pressed(&"pause"):
		flow.call("_set_state", STATE_IN_GAME)
		return true
	return false
