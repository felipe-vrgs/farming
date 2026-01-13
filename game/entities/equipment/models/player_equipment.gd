class_name PlayerEquipment
extends Resource

## PlayerEquipment
## Paperdoll-style equipment separate from inventory.
## Stores slot -> equipped item id (ItemData.id). We resolve to ItemData at runtime.

@export var equipped: Dictionary = {}  # StringName slot -> StringName item_id


static func _migrate_legacy_item_id(item_id: StringName) -> StringName:
	# Keep old saves compatible when item ids change.
	match item_id:
		&"pants_brown", &"pants_jeans":
			return &"jeans"
		_:
			return item_id


func get_equipped_item_id(slot: StringName) -> StringName:
	var v: Variant = equipped.get(slot)
	var raw: StringName = v as StringName if v is StringName else &""
	var migrated := _migrate_legacy_item_id(raw)
	if migrated != raw and not String(migrated).is_empty() and not String(slot).is_empty():
		# Persist migration so future saves don't keep legacy ids.
		equipped[slot] = migrated
	return migrated


func set_equipped_item_id(slot: StringName, item_id: StringName) -> void:
	if String(slot).is_empty():
		return
	item_id = _migrate_legacy_item_id(item_id)
	if String(item_id).is_empty():
		equipped.erase(slot)
	else:
		equipped[slot] = item_id
