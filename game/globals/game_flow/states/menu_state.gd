extends "res://game/globals/game_flow/states/game_flow_state.gd"


func enter(_prev: int) -> void:
	if flow != null and flow.has_method("_enter_menu"):
		flow.call("_enter_menu")
