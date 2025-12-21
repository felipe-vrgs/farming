class_name State
extends Node

signal animation_change_requested(animation_name: StringName)

const INPUT_DEADZONE := 0.1

@export var animation_name: StringName = &""

var parent: Player
var player_balance_config: PlayerBalanceConfig

func bind_player(new_player: Player) -> void:
	parent = new_player

func enter() -> void:
	if String(animation_name).is_empty():
		return
	if parent == null:
		return
	animation_change_requested.emit(animation_name)
	player_balance_config = parent.player_balance_config

func exit() -> void:
	pass

func process_input(_event: InputEvent) -> StringName:
	if parent == null || parent.player_input_config == null:
		return PlayerStateNames.NONE
	if _event.is_action_pressed(parent.player_input_config.action_interact):
		return PlayerStateNames.USE_TOOL
	return PlayerStateNames.NONE

func process_frame(_delta: float) -> StringName:
	return PlayerStateNames.NONE

func process_physics(_delta: float) -> StringName:
	return PlayerStateNames.NONE
