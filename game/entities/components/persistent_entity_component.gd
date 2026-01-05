class_name PersistentEntityComponent
extends Node

## Stable identity for editor-placed entities.
## Runtime: derived deterministically from (level scene path + entity node path in level).
## Note: this means renaming/reparenting authored nodes will change IDs (and can break old saves).
@export var persistent_id: StringName = &""

## Whether this entity is authored in the level scene (baseline) and should be reconciled on load.
@export var authored_in_scene: bool = true

var _runtime_id_set: bool = false


func _enter_tree() -> void:
	# Allow discovery of the component itself (used by hydration/capture helpers).
	add_to_group(Groups.PERSISTENT_ENTITY_COMPONENTS)

	# Ensure the parent is discoverable at runtime for reconciliation.
	if not Engine.is_editor_hint():
		var p := get_parent()
		if p:
			p.add_to_group(Groups.PERSISTENT_ENTITIES)
		_try_set_runtime_id()


func _ready() -> void:
	# In editor we don't auto-generate IDs because this node typically lives in a PackedScene
	# (e.g. tree.tscn), which would cause all instances to share the same baked ID.
	if Engine.is_editor_hint():
		return
	_try_set_runtime_id()


func _try_set_runtime_id() -> void:
	# Prefer deterministic IDs over any baked value (fixes legacy duplicated IDs).
	if _runtime_id_set:
		return
	var pid := _compute_deterministic_id()
	if String(pid).is_empty():
		# Scene might not be fully ready yet; try once more next frame.
		call_deferred("_try_set_runtime_id")
		return
	persistent_id = pid
	_runtime_id_set = true


func _compute_deterministic_id() -> StringName:
	var entity := get_parent()
	if entity == null:
		return &""
	var tree := get_tree()
	if tree == null:
		return &""
	var scene := tree.current_scene
	if scene == null:
		return &""
	var level_scene_path := String(scene.scene_file_path)
	if level_scene_path.is_empty():
		return &""
	# Node path relative to level root (unique for each placed instance).
	var rel_path := String(scene.get_path_to(entity))
	if rel_path.is_empty():
		return &""
	var key := "%s|%s" % [level_scene_path, rel_path]
	return _hash_md5_hex(key)


static func _hash_md5_hex(text: String) -> StringName:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(text.to_utf8_buffer())
	var digest: PackedByteArray = ctx.finish()
	return StringName(digest.hex_encode())
