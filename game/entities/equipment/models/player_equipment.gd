class_name PlayerEquipment
extends Resource

## PlayerEquipment
## Paperdoll-style equipment separate from inventory.
## Stores slot -> equipped item id (ItemData.id). We resolve to ItemData at runtime.

@export var equipped: Dictionary = {}  # StringName slot -> StringName item_id


func get_equipped_item_id(slot: StringName) -> StringName:
	var v: Variant = equipped.get(slot)
	return v as StringName if v is StringName else &""


func set_equipped_item_id(slot: StringName, item_id: StringName) -> void:
	if String(slot).is_empty():
		return
	if String(item_id).is_empty():
		equipped.erase(slot)
	else:
		equipped[slot] = item_id
