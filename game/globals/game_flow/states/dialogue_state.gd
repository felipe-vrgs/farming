extends "res://game/globals/game_flow/states/game_flow_state.gd"


func enter(_prev: int) -> void:
	if flow != null and flow.has_method("_enter_dialogue"):
		flow.call("_enter_dialogue")


func exit(_next: int) -> void:
	if flow != null and flow.has_method("_exit_dialogue"):
		flow.call("_exit_dialogue")
