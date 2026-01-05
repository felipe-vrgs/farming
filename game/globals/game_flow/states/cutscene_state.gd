extends "res://game/globals/game_flow/states/game_flow_state.gd"


func enter(_prev: int) -> void:
	if flow != null and flow.has_method("_enter_cutscene"):
		flow.call("_enter_cutscene")


func exit(_next: int) -> void:
	if flow != null and flow.has_method("_exit_cutscene"):
		flow.call("_exit_cutscene")
