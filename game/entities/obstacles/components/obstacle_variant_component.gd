@tool
class_name ObstacleVariantComponent
extends Node

## Reusable per-instance variant selector for obstacle scenes.
## - Add as a child of an `Obstacle` instance (or anything exposing `apply_preset(preset)`).
## - Provide a `catalog` (ObstacleVariantCatalog) and choose `variant_index`.
## - In the editor, `variant_index` becomes a dropdown of preset names.

var _catalog: Resource
@export var catalog: Resource:
	get:
		return _catalog
	set(v):
		if _catalog == v:
			_apply_from_catalog()
			return
		_disconnect_catalog()
		_catalog = v
		_connect_catalog()
		notify_property_list_changed()
		_apply_from_catalog()

var _variant_index: int = 0
var _apply_queued: bool = false


func _enter_tree() -> void:
	_connect_catalog()


func _exit_tree() -> void:
	_disconnect_catalog()


func _ready() -> void:
	# Ensure runtime applies even if the setter didn't fire (scene instancing/load order).
	# Defer by one tick so the parent isn't "busy setting up children" when Obstacle
	# needs to add Sprite2D/StaticBody2D/GridOccupantComponent nodes.
	_queue_apply()


func _get_property_list() -> Array[Dictionary]:
	var hint := ""
	if _catalog != null and _catalog.has_method("get_labels"):
		var labels: PackedStringArray = _catalog.call("get_labels")
		if not labels.is_empty():
			var safe: Array[String] = []
			safe.resize(labels.size())
			for i in range(labels.size()):
				# Enum hints use commas as separators; sanitize names to avoid breaking the hint string.
				var s := String(labels[i]).strip_edges()
				if s.is_empty():
					s = "Variant %d" % i
				s = s.replace(",", " ")
				safe[i] = s
			hint = ",".join(safe)

	return [
		{
			"name": "variant_index",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": hint,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
		}
	]


func _get(property: StringName) -> Variant:
	if property == &"variant_index":
		return _variant_index
	return null


func _set(property: StringName, value: Variant) -> bool:
	if property != &"variant_index":
		return false

	var idx := int(value)
	idx = _clamp_index(idx)
	if _variant_index == idx:
		return true

	_variant_index = idx
	_apply_from_catalog()
	return true


func _clamp_index(idx: int) -> int:
	if _catalog == null:
		return max(0, idx)
	var presets: Variant = _catalog.get("presets")
	if not (presets is Array):
		return max(0, idx)
	var a := presets as Array
	if a.is_empty():
		return max(0, idx)
	return clampi(idx, 0, a.size() - 1)


func _connect_catalog() -> void:
	if _catalog == null:
		return
	if not _catalog.changed.is_connected(_on_catalog_changed):
		_catalog.changed.connect(_on_catalog_changed)


func _disconnect_catalog() -> void:
	if _catalog == null:
		return
	if _catalog.changed.is_connected(_on_catalog_changed):
		_catalog.changed.disconnect(_on_catalog_changed)


func _on_catalog_changed() -> void:
	# Preset names or contents changed; refresh dropdown + re-apply.
	notify_property_list_changed()
	_queue_apply()


func _apply_from_catalog() -> void:
	_apply_queued = false
	if _catalog == null:
		return
	var idx := _clamp_index(_variant_index)
	if idx != _variant_index:
		_variant_index = idx

	if not _catalog.has_method("get_preset_by_index"):
		return
	var p: ObstaclePreset = _catalog.call("get_preset_by_index", idx)
	if p == null:
		return

	var parent := get_parent()
	if parent == null:
		return
	# Godot's static analyzer sometimes can't see methods on instanced script bases.
	# Use call() to keep tooling happy.
	if parent.has_method("apply_preset"):
		parent.call("apply_preset", p)
	else:
		push_warning("ObstacleVariantComponent parent has no apply_preset(preset) method.")


func _queue_apply() -> void:
	if _apply_queued:
		return
	if not is_inside_tree():
		return
	_apply_queued = true
	call_deferred("_apply_from_catalog")
