class_name Hotbar
extends MarginContainer

const SLOT_SCENE = preload("res://game/ui/hotbar_slot/hotbar_slot.tscn")

@export var slot_size: Vector2 = Vector2(20, 20)

@onready var container: HBoxContainer = $HBoxContainer

var _inventory: InventoryData = null
var _start_index: int = 0
var _slot_count: int = 10
var _hotkeys: Array = []
var _selected_slot_index: int = -1  # hotbar-local index (0..slot_count-1)


func rebind_inventory(
	inventory: InventoryData, start_index: int = 0, slot_count: int = 10, hotkeys: Array = []
) -> void:
	# Disconnect previous inventory.
	if _inventory != null:
		var cb := Callable(self, "_on_inventory_contents_changed")
		if _inventory.is_connected("contents_changed", cb):
			_inventory.disconnect("contents_changed", cb)

	_inventory = inventory
	_start_index = maxi(0, start_index)
	_slot_count = maxi(1, slot_count)
	_hotkeys = hotkeys

	# Connect new inventory.
	if _inventory != null and _inventory.has_signal("contents_changed"):
		var cb := Callable(self, "_on_inventory_contents_changed")
		if not _inventory.is_connected("contents_changed", cb):
			_inventory.connect("contents_changed", cb)

	_rebuild()


## Set which hotbar slot is equipped (0..slot_count-1).
## Note: this is intentionally NOT the same as InventoryPanel's selected_index.
func set_selected_index(slot_index: int) -> void:
	# Be defensive: some callers may accidentally pass an absolute inventory index.
	# We keep hotbar selection strictly in the hotbar-local range.
	if slot_index < 0:
		_selected_slot_index = -1
	else:
		_selected_slot_index = clampi(slot_index, 0, maxi(0, _slot_count - 1))
	_apply_selection()


func _on_inventory_contents_changed() -> void:
	_rebuild()


func _rebuild() -> void:
	# Clear existing slots
	for child in container.get_children():
		# Important: queue_free() is deferred; remove first so indices don't include old nodes.
		container.remove_child(child)
		child.queue_free()

	for i in range(_slot_count):
		var slot := SLOT_SCENE.instantiate()
		slot.custom_minimum_size = slot_size
		container.add_child(slot)

		if i < _hotkeys.size():
			slot.set_hotkey(_hotkeys[i])

		var abs_idx := _start_index + i
		if slot is HotbarSlot:
			(slot as HotbarSlot).setup(_inventory, abs_idx, false)
		var inv_slot: InventorySlot = null
		if _inventory != null and abs_idx >= 0 and abs_idx < _inventory.slots.size():
			inv_slot = _inventory.slots[abs_idx]

		if inv_slot != null and inv_slot.item_data != null and inv_slot.count > 0:
			# ToolData is also ItemData (inheritance). Check tool first.
			if inv_slot.item_data is ToolData:
				slot.set_tool(inv_slot.item_data as ToolData)
			else:
				slot.set_item(inv_slot.item_data, inv_slot.count)
		else:
			slot.set_item(null, 0)

		if slot is HotbarSlot:
			(slot as HotbarSlot).set_highlight(i == _selected_slot_index)

	# Ensure highlight survives rebuilds (inventory swap causes rebuild).
	_apply_selection()


func _apply_selection() -> void:
	for i in range(container.get_child_count()):
		var c := container.get_child(i)
		if c is HotbarSlot:
			(c as HotbarSlot).set_highlight(i == _selected_slot_index)
