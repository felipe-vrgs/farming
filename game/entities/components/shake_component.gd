class_name ShakeComponent
extends Node

@export var target_nodes: Array[Node2D] = []:
	set(val):
		target_nodes = val
		if is_inside_tree():
			_setup_shake()

@export var shake_strength: float = 2.0
@export var shake_duration: float = 0.2
@export var shake_decay: bool = true

var _current_strength: float = 0.0
var _timer: float = 0.0
var _is_shaking: bool = false
var _initial_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	if target_nodes.is_empty():
		var parent = get_parent()
		if parent is Node2D:
			target_nodes = [parent]


func _setup_shake() -> void:
	if target_nodes.is_empty():
		return

	for target_node in target_nodes:
		if "offset" in target_node:
			_initial_offset = target_node.offset
		else:
			_initial_offset = target_node.position


func on_shake_requested() -> void:
	start_shake(shake_strength, shake_duration)


func _process(delta: float) -> void:
	if not _is_shaking:
		return

	_timer -= delta
	if _timer <= 0:
		stop_shake()
		return

	var strength = _current_strength
	if shake_decay:
		var t = 1.0 - (_timer / shake_duration)
		strength = lerp(_current_strength, 0.0, t)

	var offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))

	for target_node in target_nodes:
		# If target is a Sprite/AnimatedSprite, it likely has an 'offset' property.
		# If not, we might be shaking the node itself (be careful with physics bodies).
		if "offset" in target_node:
			target_node.offset = _initial_offset + offset
		else:
			# Fallback: modify position (risky for PhysicsBodies, safe for plain Node2Ds)
			target_node.position = _initial_offset + offset


func start_shake(strength: float = -1.0, duration: float = -1.0) -> void:
	if target_nodes.is_empty():
		return

	_current_strength = strength if strength > 0 else shake_strength
	_timer = duration if duration > 0 else shake_duration
	_is_shaking = true
	for target_node in target_nodes:
		if "offset" in target_node:
			_initial_offset = target_node.offset
		else:
			_initial_offset = target_node.position


func stop_shake() -> void:
	_is_shaking = false
	for target_node in target_nodes:
		if "offset" in target_node:
			target_node.offset = _initial_offset
		else:
			target_node.position = _initial_offset
