@tool
class_name PersistentEntityComponent
extends Node

const GROUP_PERSISTENT_ENTITIES := &"persistent_entities"

## Stable identity for editor-placed entities.
## Generated once in-editor and saved into the scene.
@export var persistent_id: StringName = &""

## Whether this entity is authored in the level scene (baseline) and should be reconciled on load.
@export var authored_in_scene: bool = true

func _enter_tree() -> void:
	# Ensure the parent is discoverable at runtime for reconciliation.
	if not Engine.is_editor_hint():
		var p := get_parent()
		if p:
			p.add_to_group(GROUP_PERSISTENT_ENTITIES)

func _ready() -> void:
	# Auto-generate once while editing.
	if not Engine.is_editor_hint():
		return
	if not String(persistent_id).is_empty():
		return
	persistent_id = _gen_id()
	# Mark edited so the scene persists the value.
	if owner and owner.has_method("property_list_changed_notify"):
		owner.property_list_changed_notify()

func _gen_id() -> StringName:
	# 128-bit random -> hex string
	var crypto := Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(16)
	return StringName(bytes.hex_encode())


