class_name State
extends Node

signal animation_change_requested(animation_name: StringName)

const INPUT_DEADZONE := 0.1

@export var player_balance_config: PlayerBalanceConfig
@export var animation_name: StringName = &""
@export var carry_horizontal_momentum: bool = true
@export var carry_vertical_momentum: bool = false

var parent: Player

func bind_player(new_player: Player) -> void:
	parent = new_player

func enter() -> void:
	if String(animation_name).is_empty():
		return
	animation_change_requested.emit(animation_name)
	if parent == null:
		return

func exit() -> void:
	pass

func process_input(_event: InputEvent) -> StringName:
	return PlayerStateNames.NONE

func process_frame(_delta: float) -> StringName:
	return PlayerStateNames.NONE

func process_physics(_delta: float) -> StringName:
	return PlayerStateNames.NONE

func apply_carried_momentum(previous_velocity: Vector2) -> void:
	if parent == null:
		return
	if carry_horizontal_momentum:
		parent.velocity.x = previous_velocity.x
	if carry_vertical_momentum:
		parent.velocity.y = previous_velocity.y

func update_sprite_direction(horizontal_input: float) -> void:
	if parent == null:
		return
	var sprite := parent.animated_sprite
	if sprite == null:
		return
	if abs(horizontal_input) <= INPUT_DEADZONE:
		return
	sprite.flip_h = horizontal_input < 0.0
