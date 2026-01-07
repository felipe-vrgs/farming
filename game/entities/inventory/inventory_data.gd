class_name InventoryData
extends Resource

signal contents_changed

@export var slots: Array[InventorySlot] = []


## Swap two slot indices. Safe for null/empty slots.
func swap_slots(a: int, b: int) -> void:
	if a == b:
		return
	if a < 0 or b < 0:
		return
	if a >= slots.size() or b >= slots.size():
		return
	var tmp := slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	contents_changed.emit()


func add_item(item_data: ItemData, count: int = 1) -> int:
	# Try to stack first
	if item_data.stackable:
		for slot in slots:
			if slot == null:
				continue
			if slot.item_data == item_data and slot.count < item_data.max_stack:
				var space := item_data.max_stack - slot.count
				var to_add = min(space, count)
				slot.count += to_add
				count -= to_add
				if count <= 0:
					contents_changed.emit()
					return 0

	# Try to find empty slot
	for i in range(slots.size()):
		var slot = slots[i]
		if slot == null or slot.item_data == null:
			if slot == null:
				slot = InventorySlot.new()
				slots[i] = slot

			slot.item_data = item_data
			slot.count = min(item_data.max_stack, count)
			count -= slot.count
			if count <= 0:
				contents_changed.emit()
				return 0

	contents_changed.emit()
	return count  # Return remainder if inventory full


## Remove up to `count` items from a specific slot index.
## Returns the number of items actually removed.
func remove_from_slot(index: int, count: int = 1) -> int:
	if index < 0 or index >= slots.size():
		return 0
	var slot := slots[index]
	if slot == null or slot.item_data == null or slot.count <= 0:
		return 0
	var removed := mini(int(count), int(slot.count))
	if removed <= 0:
		return 0
	slot.count -= removed
	if slot.count <= 0:
		slot.count = 0
		slot.item_data = null
	contents_changed.emit()
	return removed
