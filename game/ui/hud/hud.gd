class_name HUD
extends CanvasLayer

var player: Player = null
var _tool_manager: ToolManager = null

@onready var hotbar: Hotbar = $Control/Hotbar


func _ready() -> void:
	_find_and_sync_player()


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_find_and_sync_player()


func rebind(new_player: Player = null) -> void:
	# Called by UIManager/GameFlow after loads to ensure HUD points at the new Player instance.
	player = new_player
	_find_and_sync_player()


func _find_and_sync_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if player:
		var hotkeys: Array = []
		if player.player_input_config:
			hotkeys = [
				_get_key_text(player.player_input_config.action_hotbar_1),
				_get_key_text(player.player_input_config.action_hotbar_2),
				_get_key_text(player.player_input_config.action_hotbar_3),
				_get_key_text(player.player_input_config.action_hotbar_4),
				_get_key_text(player.player_input_config.action_hotbar_5),
				_get_key_text(player.player_input_config.action_hotbar_6),
				_get_key_text(player.player_input_config.action_hotbar_7),
				_get_key_text(player.player_input_config.action_hotbar_8),
				_get_key_text(player.player_input_config.action_hotbar_9),
				_get_key_text(player.player_input_config.action_hotbar_0),
			]

		hotbar.rebind_inventory(player.inventory, 0, 10, hotkeys)

		# Bind hotbar selection to ToolManager if available.
		_rebind_tool_manager(player.tool_manager)

		# Ensure initial selection is applied (ToolManager emits selection_changed on refresh).
		call_deferred("_sync_hotbar_selection")


func _sync_hotbar_selection() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.tool_manager == null:
		return
	# Force selection sync (new game) so hotbar highlights immediately.
	if player.tool_manager.has_method("refresh_selection"):
		player.tool_manager.call("refresh_selection")
	if player.tool_manager.has_method("get_selected_hotbar_index"):
		hotbar.set_selected_index(int(player.tool_manager.call("get_selected_hotbar_index")))


func _get_key_text(action: StringName) -> String:
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return ""


func _rebind_tool_manager(tm: ToolManager) -> void:
	# Disconnect old.
	if _tool_manager != null and is_instance_valid(_tool_manager):
		var old_cb := Callable(self, "_on_hotbar_selection_changed")
		if _tool_manager.is_connected("selection_changed", old_cb):
			_tool_manager.disconnect("selection_changed", old_cb)
	_tool_manager = tm
	# Connect new.
	if _tool_manager != null and is_instance_valid(_tool_manager):
		var cb := Callable(self, "_on_hotbar_selection_changed")
		if not _tool_manager.is_connected("selection_changed", cb):
			_tool_manager.connect("selection_changed", cb)


func _on_hotbar_selection_changed(index: int, _item: ItemData) -> void:
	hotbar.set_selected_index(index)


func set_hotbar_visible(show_hotbar: bool) -> void:
	var control := get_node_or_null("Control")
	if control != null:
		control.visible = show_hotbar
