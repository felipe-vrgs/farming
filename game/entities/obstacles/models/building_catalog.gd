@tool
class_name BuildingCatalog
extends Resource

## Shared presets for buildings. Per-instance selection lives on the Building node.

enum BuildingType { BUILDING_1, BUILDING_2, BUILDING_3 }

var _presets: Array[ObstaclePreset] = []
@export var presets: Array[ObstaclePreset]:
	get:
		return _presets
	set(v):
		_disconnect_presets()
		_presets = v
		_connect_presets()
		emit_changed()

var _preset_handlers: Array[Callable] = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_POSTINITIALIZE:
		_connect_presets()


func get_preset(t: BuildingType) -> ObstaclePreset:
	var idx := int(t)
	if _presets == null or idx < 0 or idx >= _presets.size():
		return null
	return _presets[idx]


func _connect_presets() -> void:
	_preset_handlers.clear()
	if _presets == null:
		return
	for i in range(_presets.size()):
		var p := _presets[i]
		if p == null:
			_preset_handlers.append(Callable())
			continue
		var cb := _on_preset_changed.bind(i)
		_preset_handlers.append(cb)
		if not p.changed.is_connected(cb):
			p.changed.connect(cb)


func _disconnect_presets() -> void:
	if _presets == null or _preset_handlers.is_empty():
		_preset_handlers.clear()
		return
	for i in range(mini(_presets.size(), _preset_handlers.size())):
		var p := _presets[i]
		var cb := _preset_handlers[i]
		if p != null and cb.is_valid() and p.changed.is_connected(cb):
			p.changed.disconnect(cb)
	_preset_handlers.clear()


func _on_preset_changed(_idx: int) -> void:
	emit_changed()
