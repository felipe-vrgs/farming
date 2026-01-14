class_name BlacksmithInputSlot
extends HotbarSlot

signal slot_dropped(inventory: InventoryData, index: int)


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Blacksmith input slot is a drop target only.
	return null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d := data as Dictionary
	if not d.has("inventory") or not d.has("index"):
		return false
	if not (d["inventory"] is InventoryData):
		return false
	var inv := d["inventory"] as InventoryData
	var idx := int(d["index"])
	if idx < 0 or idx >= inv.slots.size():
		return false
	var slot := inv.slots[idx]
	if slot == null or slot.item_data == null:
		return false
	return slot.item_data is ToolData


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var d := data as Dictionary
	var inv := d["inventory"] as InventoryData
	var idx := int(d["index"])
	slot_dropped.emit(inv, idx)
