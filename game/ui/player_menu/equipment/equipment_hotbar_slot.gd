@tool
class_name EquipmentHotbarSlot
extends HotbarSlot

## Hotbar-styled equipment slot (no hotkey label).
## - Click / ui_accept: requests unequip.
## - Drag-drop: accepts inventory slot payloads and forwards to PlayerMenu.

@export var equipment_slot: StringName = &""


func set_hotkey(_text: String) -> void:
	# Equipment slots intentionally do not show hotkey numbers.
	super.set_hotkey("")


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Don't allow dragging equipment slots yet (unequip is click-based for now).
	return null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept the same payload as HotbarSlot drag-drop, but we are not bound to an InventoryData.
	if String(equipment_slot).is_empty():
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d := data as Dictionary
	return d.has("inventory") and d.has("index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if owner != null and owner.has_method("_on_equipment_slot_drop"):
		owner.call("_on_equipment_slot_drop", equipment_slot, data)


func _gui_input(event: InputEvent) -> void:
	if event == null:
		return

	# Click to unequip.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_request_unequip()
			accept_event()
			return

	# Keyboard accept (if focused) also unequips.
	if event.is_action_pressed(&"ui_accept", false, true):
		_request_unequip()
		accept_event()
		return


func _request_unequip() -> void:
	if String(equipment_slot).is_empty():
		return
	if owner != null and owner.has_method("_on_equipped_slot_pressed"):
		owner.call("_on_equipped_slot_pressed", equipment_slot)
