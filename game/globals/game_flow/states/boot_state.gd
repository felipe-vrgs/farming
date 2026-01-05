extends "res://game/globals/game_flow/states/game_flow_state.gd"


func enter(_prev: int) -> void:
	# No-op. Boot is a transient state; GameFlow will move to MENU in normal runs.
	pass
