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
		var target_id: StringName = item_data.id
		for slot in slots:
			if slot == null:
				continue
			# Stack by stable item id (not resource identity) so duplicates still stack.
			if (
				slot.item_data != null
				and slot.item_data.id == target_id
				and slot.count < item_data.max_stack
			):
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


## Count items by stable item id across all slots.
func count_item_id(item_id: StringName) -> int:
	if String(item_id).is_empty():
		return 0
	var total := 0
	for s in slots:
		if s == null or s.item_data == null or s.count <= 0:
			continue
		if s.item_data.id == item_id:
			total += int(s.count)
	return total


## Find the first slot index containing an item id (count > 0). Returns -1 if not found.
func find_slot_with_item_id(item_id: StringName) -> int:
	if String(item_id).is_empty():
		return -1
	for i in range(slots.size()):
		var s := slots[i]
		if s == null or s.item_data == null or s.count <= 0:
			continue
		if s.item_data.id == item_id:
			return i
	return -1


## Remove up to `count` items with the given id across all slots.
## Returns the number of items actually removed.
func remove_item_id(item_id: StringName, count: int = 1) -> int:
	if String(item_id).is_empty():
		return 0
	var remaining := maxi(0, int(count))
	if remaining <= 0:
		return 0
	var removed_total := 0
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var s := slots[i]
		if s == null or s.item_data == null or s.count <= 0:
			continue
		if s.item_data.id != item_id:
			continue
		var take := mini(int(s.count), remaining)
		s.count -= take
		removed_total += take
		remaining -= take
		if s.count <= 0:
			s.count = 0
			s.item_data = null
	if removed_total > 0:
		contents_changed.emit()
	return removed_total
