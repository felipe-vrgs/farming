class_name PlayerInputConfig
extends Resource

# Movement actions
@export var action_move_left: StringName = "move_left"
@export var action_move_right: StringName = "move_right"
@export var action_move_up: StringName = "move_up"
@export var action_move_down: StringName = "move_down"
@export var action_pause: StringName = "pause"

# Movement keys
@export var move_left_keys: Array[Key] = [KEY_A, KEY_LEFT]
@export var move_right_keys: Array[Key] = [KEY_D, KEY_RIGHT]
@export var move_up_keys: Array[Key] = [KEY_W, KEY_UP]
@export var move_down_keys: Array[Key] = [KEY_S, KEY_DOWN]
@export var pause_keys: Array[Key] = [KEY_ESCAPE, KEY_P]

var keyboard_actions_map: Dictionary = {
	action_move_left: move_left_keys,
	action_move_right: move_right_keys,
	action_move_up: move_up_keys,
	action_move_down: move_down_keys,
	action_pause: pause_keys,
}

var mouse_actions_map: Dictionary = {
}

func ensure_actions_registered() -> void:
	for action_name in keyboard_actions_map.keys():
		_register_key_bindings(action_name, keyboard_actions_map[action_name])
	for action_name in mouse_actions_map.keys():
		_register_mouse_bindings(action_name, mouse_actions_map[action_name])

func _register_key_bindings(action_name: StringName, keys: Array[Key]) -> void:
	_ensure_action_exists(action_name)
	for keycode in keys:
		if _has_key_event(action_name, keycode):
			continue

		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

func _register_mouse_bindings(action_name: StringName, buttons: Array[MouseButton]) -> void:
	_ensure_action_exists(action_name)
	for button in buttons:
		if _has_mouse_button_event(action_name, button):
			continue

		var event := InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action_name, event)

static func _ensure_action_exists(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

static func _has_key_event(action_name: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false

static func _has_mouse_button_event(action_name: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false
