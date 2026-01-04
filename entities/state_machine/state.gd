class_name State
extends Node

@warning_ignore("unused_signal")
signal animation_change_requested(animation_name: StringName)

const INPUT_DEADZONE := 0.1

var parent: Node


func bind_parent(new_parent: Node) -> void:
	parent = new_parent


func enter() -> void:
	pass


func exit() -> void:
	pass


func process_input(_event: InputEvent) -> StringName:
	return &""


func process_frame(_delta: float) -> StringName:
	return &""


func process_physics(_delta: float) -> StringName:
	return &""
