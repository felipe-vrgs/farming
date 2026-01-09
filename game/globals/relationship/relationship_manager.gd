extends Node

## RelationshipManager
## - Owns relationship progress per NPC (half-heart units: 0..20)
## - Bootstraps NPC ids from `res://game/entities/npc/configs/`
## - Persists via RelationshipsSave through SaveManager/Runtime autosave
## - Emits EventBus.relationship_changed(npc_id, units) on changes

const _NPC_CONFIGS_DIR := "res://game/entities/npc/configs"

const MIN_UNITS := 0
const MAX_UNITS := 20

var _units_by_npc: Dictionary[StringName, int] = {}  # npc_id -> int (0..20)
var _sorted_npc_ids: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bootstrap_from_npc_configs()


# region Public API


func list_npc_ids() -> Array[StringName]:
	# Return a stable sorted copy.
	var out: Array[StringName] = []
	for id in _sorted_npc_ids:
		out.append(id)
	return out


func has_npc(npc_id: StringName) -> bool:
	return _units_by_npc.has(npc_id)


func get_units(npc_id: StringName) -> int:
	if String(npc_id).is_empty():
		return 0
	return int(_units_by_npc.get(npc_id, 0))


func set_units(npc_id: StringName, units: int) -> void:
	if String(npc_id).is_empty():
		return
	_ensure_npc(npc_id)
	var next := clampi(int(units), MIN_UNITS, MAX_UNITS)
	var cur := int(_units_by_npc.get(npc_id, 0))
	if next == cur:
		return
	_units_by_npc[npc_id] = next
	_emit_changed(npc_id, next)


func add_units(npc_id: StringName, delta_units: int) -> int:
	if String(npc_id).is_empty():
		return 0
	_ensure_npc(npc_id)
	var cur := int(_units_by_npc.get(npc_id, 0))
	var next := clampi(cur + int(delta_units), MIN_UNITS, MAX_UNITS)
	if next == cur:
		return cur
	_units_by_npc[npc_id] = next
	_emit_changed(npc_id, next)
	return next


func reset_for_new_game() -> void:
	_units_by_npc.clear()
	_sorted_npc_ids.clear()
	_bootstrap_from_npc_configs()


func get_npc_config(npc_id: StringName) -> NpcConfig:
	if String(npc_id).is_empty():
		return null
	var p := _npc_config_path(npc_id)
	if not ResourceLoader.exists(p):
		return null
	var res := load(p)
	return res as NpcConfig


func capture_state() -> RelationshipsSave:
	var save := RelationshipsSave.new()
	var out: Dictionary = {}
	for k in _units_by_npc.keys():
		var id := String(k)
		if id.is_empty():
			continue
		out[id] = clampi(int(_units_by_npc[k]), MIN_UNITS, MAX_UNITS)
	save.values = out
	return save


func hydrate_state(save: RelationshipsSave) -> void:
	reset_for_new_game()
	if save == null:
		return
	if "values" not in save:
		return
	if not (save.values is Dictionary):
		return
	for k in (save.values as Dictionary).keys():
		var npc_id := StringName(String(k))
		if String(npc_id).is_empty():
			continue
		var v: Variant = (save.values as Dictionary)[k]
		var units := 0
		if v is int:
			units = int(v)
		elif v is float:
			units = int(v)
		else:
			units = int(String(v).to_int())
		set_units(npc_id, units)


# endregion

# region Internals


func _emit_changed(npc_id: StringName, units: int) -> void:
	if EventBus != null and "relationship_changed" in EventBus:
		EventBus.relationship_changed.emit(npc_id, int(units))


func _ensure_npc(npc_id: StringName) -> void:
	if _units_by_npc.has(npc_id):
		return
	_units_by_npc[npc_id] = 0
	_sorted_npc_ids.append(npc_id)
	_sorted_npc_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool: return String(a) < String(b)
	)


func _bootstrap_from_npc_configs() -> void:
	var ids := _scan_npc_configs_dir(_NPC_CONFIGS_DIR)
	_sorted_npc_ids.clear()
	for id in ids:
		if String(id).is_empty():
			continue
		if not _units_by_npc.has(id):
			_units_by_npc[id] = 0
	_sorted_npc_ids = ids
	_sorted_npc_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool: return String(a) < String(b)
	)


func _scan_npc_configs_dir(dir_path: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var da := DirAccess.open(dir_path)
	if da == null:
		return out
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry == "." or entry == ".." or entry.begins_with("."):
			entry = da.get_next()
			continue
		if da.current_is_dir():
			# No recursion needed for now; keep simple.
			entry = da.get_next()
			continue
		if entry.ends_with(".tres"):
			var path := "%s/%s" % [dir_path, entry]
			var res := load(path)
			if res is NpcConfig:
				var cfg := res as NpcConfig
				if cfg != null and cfg.is_valid():
					out.append(cfg.npc_id)
		entry = da.get_next()
	da.list_dir_end()
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func _npc_config_path(npc_id: StringName) -> String:
	return "%s/%s.tres" % [_NPC_CONFIGS_DIR, String(npc_id)]

# endregion
