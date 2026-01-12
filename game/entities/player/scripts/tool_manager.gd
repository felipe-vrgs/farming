class_name ToolManager
extends Node

signal selection_changed(index: int, item: ItemData)

## Minimum time (in seconds) between tool uses.
@export var tool_cooldown: float = 0.2

var player: Player
var _placement_manager: Node = null

var _selected_hotbar_index: int = 0
var _selected_item: ItemData = null
var _selected_tool: ToolData = null

var _tool_cooldown_timer: float = 0.0


func _ready() -> void:
	player = owner as Player
	_placement_manager = get_node_or_null("../PlacementManager")
	# Defer selection until Player.tool_node is ready.
	call_deferred("_setup_connections")


func _setup_connections() -> void:
	if player != null and player.inventory != null:
		if not player.inventory.contents_changed.is_connected(refresh_selection):
			player.inventory.contents_changed.connect(refresh_selection)
	refresh_selection()


func _process(delta: float) -> void:
	if _tool_cooldown_timer > 0:
		_tool_cooldown_timer -= delta


func equip_tool(data: ToolData) -> void:
	if not player or not player.tool_node:
		return
	_selected_tool = data
	player.tool_node.data = data
	# Tool visuals are shown only during tool use (charging/swing), not while walking.
	if player.tool_node.has_method("set_held_tool"):
		player.tool_node.call("set_held_tool", data)
	if EventBus:
		EventBus.player_tool_equipped.emit(data)


func start_tool_cooldown(duration: float = -1.0) -> void:
	if duration < 0:
		_tool_cooldown_timer = tool_cooldown
	else:
		_tool_cooldown_timer = duration


func can_use_tool() -> bool:
	return _tool_cooldown_timer <= 0.0


func select_hotbar_slot(index: int) -> void:
	# Hotbar is inventory slots 0-9.
	_selected_hotbar_index = clampi(index, 0, 9)
	refresh_selection()


## Back-compat API: older save/hydration uses tool_id + seed_id.
## We now persist the selected hotbar index implicitly by the slot contents.
func get_selected_tool_id() -> StringName:
	if _selected_item is ToolData:
		return (_selected_item as ToolData).id
	return &""


func get_selected_seed_id() -> StringName:
	# Seed selection is now item-driven (SeedItemData) so this is unused.
	return &""


func apply_selection(tool_id: StringName, _seed_id: StringName) -> void:
	# Try to restore the selected hotbar index by finding the tool in slots 0-9.
	if player == null or player.inventory == null:
		return
	if String(tool_id).is_empty():
		return
	var slots := player.inventory.slots
	for i in range(mini(10, slots.size())):
		var s: InventorySlot = slots[i]
		if s == null or s.item_data == null or s.count <= 0:
			continue
		if s.item_data is ToolData and (s.item_data as ToolData).id == tool_id:
			_selected_hotbar_index = i
			refresh_selection()
			return


func refresh_selection() -> void:
	var item := _get_hotbar_item(_selected_hotbar_index)
	_selected_item = item

	# Tool vs item mode.
	if item == null:
		# Empty slot.
		equip_tool(null)
		_set_item_mode(null)
		if player != null and player.has_method("set_carried_item"):
			player.call("set_carried_item", null)
		if player != null and player.state_machine != null:
			player.state_machine.change_state(PlayerStateNames.IDLE)
	elif item is ToolData:
		_set_item_mode(null)
		equip_tool(item as ToolData)
		if player != null and player.has_method("set_carried_item"):
			player.call("set_carried_item", null)
		# Ensure we aren't stuck in placement state.
		if player != null and player.state_machine != null:
			if (
				player.state_machine.current_state != null
				and String(player.state_machine.current_state.name).to_snake_case() == &"placement"
			):
				player.state_machine.change_state(PlayerStateNames.IDLE)
	elif item is ClothingItemData:
		# Clothes are not "carried items" and should not enter placement/carry animations.
		equip_tool(null)
		_set_item_mode(null)
		if player != null and player.has_method("set_carried_item"):
			player.call("set_carried_item", null)
		# Ensure we aren't stuck in placement state.
		if player != null and player.state_machine != null:
			if (
				player.state_machine.current_state != null
				and String(player.state_machine.current_state.name).to_snake_case() == &"placement"
			):
				player.state_machine.change_state(PlayerStateNames.IDLE)
	else:
		# Carry / placement mode.
		equip_tool(null)
		_set_item_mode(item)
		if player != null and player.has_method("set_carried_item"):
			player.call("set_carried_item", item)
		if player != null and player.state_machine != null:
			player.state_machine.change_state(&"placement")

	selection_changed.emit(_selected_hotbar_index, _selected_item)


func get_selected_hotbar_index() -> int:
	return _selected_hotbar_index


func get_selected_item() -> ItemData:
	return _selected_item


func get_selected_tool() -> ToolData:
	return _selected_tool


func is_in_item_mode() -> bool:
	return (
		_selected_item != null
		and not (_selected_item is ToolData)
		and not (_selected_item is ClothingItemData)
	)


func _set_item_mode(item: ItemData) -> void:
	if _placement_manager == null:
		return
	if item == null:
		if _placement_manager.has_method("clear_carried"):
			_placement_manager.call("clear_carried")
	else:
		if _placement_manager.has_method("set_carried"):
			_placement_manager.call("set_carried", item, _selected_hotbar_index)


func _get_hotbar_item(index: int) -> ItemData:
	if player == null or player.inventory == null:
		return null
	if index < 0 or index >= player.inventory.slots.size():
		return null
	var slot: InventorySlot = player.inventory.slots[index]
	if slot == null or slot.item_data == null or slot.count <= 0:
		return null
	return slot.item_data
