extends Node

const DEFAULT_SAVE_PATH := "user://savegame.tres"  # kept only for signature compatibility

const DEFAULT_SLOT := "default"
const DEFAULT_SESSION := "current"

var _current_slot: String = DEFAULT_SLOT
var _session_id: String = DEFAULT_SESSION


func _ready() -> void:
	pass


func set_slot(slot: String) -> void:
	_current_slot = slot if not slot.is_empty() else DEFAULT_SLOT


func set_session(session_id: String) -> void:
	_session_id = session_id if not session_id.is_empty() else DEFAULT_SESSION


func slot_exists(slot: String) -> bool:
	var s := slot if not slot.is_empty() else DEFAULT_SLOT
	return DirAccess.dir_exists_absolute(_slot_root(s))


func list_slots() -> Array[String]:
	var out: Array[String] = []
	var root := "user://saves"
	if not DirAccess.dir_exists_absolute(root):
		return out
	var da := DirAccess.open(root)
	if da == null:
		return out
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if da.current_is_dir() and entry != "." and entry != "..":
			out.append(entry)
		entry = da.get_next()
	da.list_dir_end()
	out.sort()
	return out


func delete_slot(slot: String) -> bool:
	var s := slot if not slot.is_empty() else DEFAULT_SLOT
	var path := _slot_root(s)
	if not DirAccess.dir_exists_absolute(path):
		return false
	_delete_dir_recursive(path)
	return true


func get_slot_modified_unix(slot: String) -> int:
	# Best-effort: use game.tres mtime; falls back to 0 if missing.
	var s := slot if not slot.is_empty() else DEFAULT_SLOT
	var p := "%s/game.tres" % _slot_root(s)
	if not FileAccess.file_exists(p):
		return 0
	return int(FileAccess.get_modified_time(p))


# endregion


# region Session / Slot IO
func copy_session_to_slot(slot: String) -> bool:
	var s := slot if not slot.is_empty() else DEFAULT_SLOT
	return _copy_dir_recursive(_session_root(), _slot_root(s))


func copy_slot_to_session(slot: String) -> bool:
	var s := slot if not slot.is_empty() else DEFAULT_SLOT
	var src := _slot_root(s)
	if not DirAccess.dir_exists_absolute(src):
		return false
	reset_session()
	return _copy_dir_recursive(src, _session_root())


func reset_session() -> void:
	_delete_dir_recursive(_session_root())
	_ensure_dir(_session_levels_dir())


func save_session_game_save(gs: GameSave) -> bool:
	_ensure_dir(_session_root())
	return ResourceSaver.save(gs, _session_game_save_path()) == OK


func load_session_game_save() -> GameSave:
	var path := _session_game_save_path()
	if not FileAccess.file_exists(path):
		return null
	# IMPORTANT: session files can be overwritten at runtime (e.g. load slot copies slot->session).
	# Avoid returning stale cached resources.
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return res as GameSave


func save_session_agents_save(a: AgentsSave) -> bool:
	_ensure_dir(_session_root())
	var path := _session_agents_save_path()
	var err := ResourceSaver.save(a, path)
	if err != OK:
		push_error("SaveManager: Failed to save AgentsSave to '%s' err=%s" % [path, str(err)])
		return false
	return true


func load_session_agents_save() -> AgentsSave:
	var path := _session_agents_save_path()
	if not FileAccess.file_exists(path):
		return null
	# IMPORTANT: session files can be overwritten at runtime (e.g. load slot copies slot->session).
	# Avoid returning stale cached resources.
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return null
	return res as AgentsSave


func load_slot_game_save(slot: String) -> GameSave:
	var s := slot if not slot.is_empty() else DEFAULT_SLOT
	var path := _slot_game_save_path(s)
	if not FileAccess.file_exists(path):
		return null
	# Slots can also be overwritten during play (save-to-slot), so bypass cache.
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return res as GameSave


func load_slot_agents_save(slot: String) -> AgentsSave:
	var s := slot if not slot.is_empty() else DEFAULT_SLOT
	var path := _slot_agents_save_path(s)
	if not FileAccess.file_exists(path):
		return null
	# Slots can also be overwritten during play (save-to-slot), so bypass cache.
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return res as AgentsSave


func save_session_dialogue_save(ds: DialogueSave) -> bool:
	_ensure_dir(_session_root())
	var path := _session_dialogue_save_path()
	var err := ResourceSaver.save(ds, path)
	if err != OK:
		push_error("SaveManager: Failed to save DialogueSave to '%s' err=%s" % [path, str(err)])
		return false
	return true


func load_session_dialogue_save() -> DialogueSave:
	var path := _session_dialogue_save_path()
	if not FileAccess.file_exists(path):
		return null
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return res as DialogueSave


func save_session_quest_save(qs: QuestSave) -> bool:
	_ensure_dir(_session_root())
	var path := _session_quest_save_path()
	var err := ResourceSaver.save(qs, path)
	if err != OK:
		push_error("SaveManager: Failed to save QuestSave to '%s' err=%s" % [path, str(err)])
		return false
	return true


func load_session_quest_save() -> QuestSave:
	var path := _session_quest_save_path()
	if not FileAccess.file_exists(path):
		return null
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return res as QuestSave


func load_slot_level_save(slot: String, level_id: Enums.Levels) -> LevelSave:
	var s := slot if not slot.is_empty() else DEFAULT_SLOT
	var path := _slot_level_save_path(s, level_id)
	if not FileAccess.file_exists(path):
		return null
	# Slots can also be overwritten during play (save-to-slot), so bypass cache.
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return res as LevelSave


func list_slot_level_ids(slot: String) -> Array[Enums.Levels]:
	var out: Array[Enums.Levels] = []
	var s := slot if not slot.is_empty() else DEFAULT_SLOT
	var dir_path := _slot_levels_dir(s)
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	var da := DirAccess.open(dir_path)
	if da == null:
		return out
	da.list_dir_begin()
	var file := da.get_next()
	while file != "":
		if not da.current_is_dir() and file.ends_with(".tres"):
			var stem := file.trim_suffix(".tres")
			var level_id_v: Enums.Levels = Enums.Levels.NONE
			if stem.is_valid_int():
				level_id_v = int(stem) as Enums.Levels
			if level_id_v != Enums.Levels.NONE:
				out.append(level_id_v)
		file = da.get_next()
	da.list_dir_end()
	return out


func save_session_level_save(ls: LevelSave) -> bool:
	_ensure_dir(_session_levels_dir())
	return ResourceSaver.save(ls, _session_level_save_path(ls.level_id)) == OK


func load_session_level_save(level_id: Enums.Levels) -> LevelSave:
	var path := _session_level_save_path(level_id)
	if not FileAccess.file_exists(path):
		return null
	# IMPORTANT: session files can be overwritten at runtime (e.g. load slot copies slot->session).
	# Avoid returning stale cached resources.
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return res as LevelSave


func list_session_level_ids() -> Array[Enums.Levels]:
	var out: Array[Enums.Levels] = []
	var dir_path := _session_levels_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	var da := DirAccess.open(dir_path)
	if da == null:
		return out
	da.list_dir_begin()
	var file := da.get_next()
	while file != "":
		if not da.current_is_dir() and file.ends_with(".tres"):
			var stem := file.trim_suffix(".tres")
			var level_id: Enums.Levels = Enums.Levels.NONE

			# New format: enum int serialized in filename (e.g. "1.tres").
			if stem.is_valid_int():
				level_id = int(stem) as Enums.Levels

			if level_id != Enums.Levels.NONE:
				out.append(level_id)
		file = da.get_next()
	da.list_dir_end()
	return out


# endregion


# region Paths + file ops (private)
func _session_root() -> String:
	return "user://sessions/%s" % _session_id


func _slot_root(slot: String) -> String:
	return "user://saves/%s" % slot


func _session_game_save_path() -> String:
	return "%s/game.tres" % _session_root()


func _session_agents_save_path() -> String:
	return "%s/agents.tres" % _session_root()


func _session_dialogue_save_path() -> String:
	return "%s/dialogue.tres" % _session_root()


func _session_quest_save_path() -> String:
	return "%s/quests.tres" % _session_root()


func _session_levels_dir() -> String:
	return "%s/levels" % _session_root()


func _session_level_save_path(level_id: Enums.Levels) -> String:
	return "%s/%s.tres" % [_session_levels_dir(), level_id]


func _slot_game_save_path(slot: String) -> String:
	return "%s/game.tres" % _slot_root(slot)


func _slot_agents_save_path(slot: String) -> String:
	return "%s/agents.tres" % _slot_root(slot)


func _slot_levels_dir(slot: String) -> String:
	return "%s/levels" % _slot_root(slot)


func _slot_level_save_path(slot: String, level_id: Enums.Levels) -> String:
	return "%s/%s.tres" % [_slot_levels_dir(slot), level_id]


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


func _delete_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = da.get_next()
			continue
		var full := "%s/%s" % [path, entry]
		if da.current_is_dir():
			_delete_dir_recursive(full)
			DirAccess.remove_absolute(full)
		else:
			DirAccess.remove_absolute(full)
		entry = da.get_next()
	da.list_dir_end()
	DirAccess.remove_absolute(path)


func _copy_dir_recursive(src: String, dst: String) -> bool:
	if not DirAccess.dir_exists_absolute(src):
		return false
	_ensure_dir(dst)
	var da := DirAccess.open(src)
	if da == null:
		return false
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = da.get_next()
			continue
		var from := "%s/%s" % [src, entry]
		var to := "%s/%s" % [dst, entry]
		if da.current_is_dir():
			if not _copy_dir_recursive(from, to):
				return false
		else:
			var bytes := FileAccess.get_file_as_bytes(from)
			var f := FileAccess.open(to, FileAccess.WRITE)
			if f == null:
				return false
			f.store_buffer(bytes)
			f.close()
		entry = da.get_next()
	da.list_dir_end()
	return true
# endregion
