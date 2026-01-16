class_name PlayerEquipment
extends Resource

## PlayerEquipment
## Paperdoll-style equipment separate from inventory.
## Stores slot -> equipped item id (ItemData.id). We resolve to ItemData at runtime.

@export var equipped: Dictionary = {}  # StringName slot -> StringName item_id


func get_equipped_item_id(slot: StringName) -> StringName:
	var v: Variant = equipped.get(slot)
	if v == null:
		v = equipped.get(String(slot))
	var raw: StringName = v as StringName if v is StringName else &""
	return raw


func set_equipped_item_id(slot: StringName, item_id: StringName) -> void:
	if String(slot).is_empty():
		return
	equipped[slot] = item_id
