class_name ItemResolver
extends Object

## Centralized lookup for ItemData by id.
## Convention: item resources live at:
## - res://game/entities/items/resources/<id>.tres
## - res://game/entities/tools/data/<id>.tres

static var _cache: Dictionary = {}  # StringName -> ItemData


static func resolve(item_id: StringName) -> ItemData:
	if String(item_id).is_empty():
		return null
	if _cache.has(item_id):
		return _cache[item_id] as ItemData

	var id_str := String(item_id)
	var candidates := PackedStringArray(
		[
			"res://game/entities/items/resources/%s.tres" % id_str,
			"res://game/entities/tools/data/%s.tres" % id_str,
		]
	)
	var resolved: ItemData = null
	for p in candidates:
		if ResourceLoader.exists(p):
			var res := load(p)
			if res is ItemData:
				resolved = res as ItemData
				break
	_cache[item_id] = resolved
	return resolved
