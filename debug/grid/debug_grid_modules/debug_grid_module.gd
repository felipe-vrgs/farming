class_name DebugGridModule
extends RefCounted

var _debug_grid: Node2D
var _font: Font


func setup(debug_grid: Node2D, font: Font) -> void:
	_debug_grid = debug_grid
	_font = font


func _input(_event: InputEvent) -> void:
	pass


func _draw(_tile_size: Vector2) -> void:
	pass


func _update_hud(_lines: Array[String]) -> void:
	pass


func _on_poll_timer_timeout() -> void:
	pass


func _get_enum_string(enum_dict: Dictionary, value: int) -> String:
	var k = enum_dict.find_key(value)
	return k if k != null else str(value)
