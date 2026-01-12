extends TextureButton

@export var equipment_slot: StringName = &""


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept inventory slot drag payloads (from HotbarSlot).
	if String(equipment_slot).is_empty():
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d := data as Dictionary
	return d.has("inventory") and d.has("index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if owner != null and owner.has_method("_on_equipment_slot_drop"):
		owner.call("_on_equipment_slot_drop", equipment_slot, data)
