class_name HUD
extends CanvasLayer

var player: Player = null
var _tool_manager: ToolManager = null
var _inventory: InventoryData = null

@onready var hotbar: Hotbar = $Control/Hotbar
@onready var energy_bar: EnergyBar = $Control/EnergyBar


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
		if energy_bar != null:
			energy_bar.rebind(player)

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

		# Keep hotbar highlight stable across inventory reorders.
		_rebind_inventory(player.inventory)

		# Bind hotbar selection to ToolManager if available.
		_rebind_tool_manager(player.tool_manager)

		# Ensure initial selection is applied (ToolManager emits selection_changed on refresh).
		call_deferred("_sync_hotbar_selection")
	else:
		if energy_bar != null:
			energy_bar.rebind(null)


func _sync_hotbar_selection() -> void:
	_apply_hotbar_selected_index()


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


func _rebind_inventory(inv: InventoryData) -> void:
	# Disconnect old.
	if _inventory != null and is_instance_valid(_inventory):
		var old_cb := Callable(self, "_on_inventory_contents_changed")
		if _inventory.is_connected("contents_changed", old_cb):
			_inventory.disconnect("contents_changed", old_cb)

	_inventory = inv

	# Connect new.
	if _inventory != null and is_instance_valid(_inventory):
		var cb := Callable(self, "_on_inventory_contents_changed")
		if not _inventory.is_connected("contents_changed", cb):
			_inventory.connect("contents_changed", cb)


func _on_inventory_contents_changed() -> void:
	# Inventory reorders rebuild the hotbar slots; apply selection after rebuild.
	call_deferred("_apply_hotbar_selected_index")


func _apply_hotbar_selected_index() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.tool_manager == null or not is_instance_valid(player.tool_manager):
		return
	if not player.tool_manager.has_method("get_selected_hotbar_index"):
		return
	hotbar.set_selected_index(int(player.tool_manager.call("get_selected_hotbar_index")))


func _on_hotbar_selection_changed(index: int, _item: ItemData) -> void:
	hotbar.set_selected_index(index)


func set_hotbar_visible(show_hotbar: bool) -> void:
	var control := get_node_or_null("Control")
	if control != null:
		control.visible = show_hotbar
