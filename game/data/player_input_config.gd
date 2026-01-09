class_name PlayerInputConfig
extends Resource

# Actions
@export var action_move_left: StringName = "move_left"
@export var action_move_right: StringName = "move_right"
@export var action_move_up: StringName = "move_up"
@export var action_move_down: StringName = "move_down"
@export var action_interact: StringName = "interact"
@export var action_use: StringName = "use"
@export var action_pause: StringName = "pause"
@export var action_open_player_menu: StringName = "open_player_menu"
@export var action_open_player_menu_inventory: StringName = "open_player_menu_inventory"
@export var action_open_player_menu_quests: StringName = "open_player_menu_quests"
@export var action_open_player_menu_relationships: StringName = "open_player_menu_relationships"
@export var action_hotbar_1: StringName = "hotbar_1"
@export var action_hotbar_2: StringName = "hotbar_2"
@export var action_hotbar_3: StringName = "hotbar_3"
@export var action_hotbar_4: StringName = "hotbar_4"
@export var action_hotbar_5: StringName = "hotbar_5"
@export var action_hotbar_6: StringName = "hotbar_6"
@export var action_hotbar_7: StringName = "hotbar_7"
@export var action_hotbar_8: StringName = "hotbar_8"
@export var action_hotbar_9: StringName = "hotbar_9"
@export var action_hotbar_0: StringName = "hotbar_0"

# Keyboard keys
@export var move_left_keys: Array[Key] = [KEY_A, KEY_LEFT]
@export var move_right_keys: Array[Key] = [KEY_D, KEY_RIGHT]
@export var move_up_keys: Array[Key] = [KEY_W, KEY_UP]
@export var move_down_keys: Array[Key] = [KEY_S, KEY_DOWN]
@export var interact_keys: Array[Key] = [KEY_E]
@export var use_keys: Array[Key] = [KEY_F]
@export var pause_keys: Array[Key] = [KEY_ESCAPE, KEY_P]
@export var open_player_menu_keys: Array[Key] = [KEY_TAB]
@export var open_player_menu_inventory_keys: Array[Key] = [KEY_I]
@export var open_player_menu_quests_keys: Array[Key] = [KEY_Q]
@export var open_player_menu_relationships_keys: Array[Key] = [KEY_R]
@export var hotbar_1_keys: Array[Key] = [KEY_1, KEY_KP_1]
@export var hotbar_2_keys: Array[Key] = [KEY_2, KEY_KP_2]
@export var hotbar_3_keys: Array[Key] = [KEY_3, KEY_KP_3]
@export var hotbar_4_keys: Array[Key] = [KEY_4, KEY_KP_4]
@export var hotbar_5_keys: Array[Key] = [KEY_5, KEY_KP_5]
@export var hotbar_6_keys: Array[Key] = [KEY_6, KEY_KP_6]
@export var hotbar_7_keys: Array[Key] = [KEY_7, KEY_KP_7]
@export var hotbar_8_keys: Array[Key] = [KEY_8, KEY_KP_8]
@export var hotbar_9_keys: Array[Key] = [KEY_9, KEY_KP_9]
@export var hotbar_0_keys: Array[Key] = [KEY_0, KEY_KP_0]
# Mouse buttons
@export var interact_mouse_buttons: Array[MouseButton] = [MOUSE_BUTTON_LEFT]
@export var use_mouse_buttons: Array[MouseButton] = [MOUSE_BUTTON_RIGHT]

var keyboard_actions_map: Dictionary = {
	action_move_left: move_left_keys,
	action_move_right: move_right_keys,
	action_move_up: move_up_keys,
	action_move_down: move_down_keys,
	action_interact: interact_keys,
	action_use: use_keys,
	action_pause: pause_keys,
	action_open_player_menu: open_player_menu_keys,
	action_open_player_menu_inventory: open_player_menu_inventory_keys,
	action_open_player_menu_quests: open_player_menu_quests_keys,
	action_open_player_menu_relationships: open_player_menu_relationships_keys,
	action_hotbar_1: hotbar_1_keys,
	action_hotbar_2: hotbar_2_keys,
	action_hotbar_3: hotbar_3_keys,
	action_hotbar_4: hotbar_4_keys,
	action_hotbar_5: hotbar_5_keys,
	action_hotbar_6: hotbar_6_keys,
	action_hotbar_7: hotbar_7_keys,
	action_hotbar_8: hotbar_8_keys,
	action_hotbar_9: hotbar_9_keys,
	action_hotbar_0: hotbar_0_keys,
}

var mouse_actions_map: Dictionary = {
	action_interact: interact_mouse_buttons,
	action_use: use_mouse_buttons,
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
