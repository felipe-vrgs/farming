extends Node

## QuestManager
## - Owns runtime quest state (active + completed)
## - Emits EventBus signals when state changes
## - Does NOT write Dialogic variables directly (DialogueManager owns that sync rule)

const _QUESTLINES_DIR := "res://game/data/quests"

var _quest_defs: Dictionary = {}  # StringName -> QuestResource
var _active: Dictionary = {}  # StringName -> int (current step index, 0-based)
var _completed: Dictionary = {}  # StringName -> bool (set semantics)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_quest_definitions()


#region Public API (game-facing)


func list_active_quests() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _active.keys():
		out.append(k as StringName)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func list_completed_quests() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _completed.keys():
		out.append(k as StringName)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func is_quest_active(quest_id: StringName) -> bool:
	return _active.has(quest_id)


func is_quest_completed(quest_id: StringName) -> bool:
	return _completed.has(quest_id)


func get_active_quest_step(quest_id: StringName) -> int:
	if not _active.has(quest_id):
		return -1
	return int(_active[quest_id])


func start_new_quest(quest_id: StringName) -> bool:
	if String(quest_id).is_empty():
		return false
	if _active.has(quest_id) or _completed.has(quest_id):
		return false
	_active[quest_id] = 0
	if EventBus != null and "quest_started" in EventBus:
		EventBus.quest_started.emit(quest_id)
	return true


## Completes the current step and advances to the next.
## Returns false if the quest is not active.
func advance_quest(quest_id: StringName, steps: int = 1) -> bool:
	if String(quest_id).is_empty():
		return false
	if steps <= 0:
		return true
	if not _active.has(quest_id):
		return false

	for _i in range(steps):
		if not _active.has(quest_id):
			break
		var completed_step := int(_active[quest_id])
		if EventBus != null and "quest_step_completed" in EventBus:
			EventBus.quest_step_completed.emit(quest_id, completed_step)

		var next_step := completed_step + 1
		var def: QuestResource = get_quest_definition(quest_id)
		if def != null and next_step >= def.steps.size():
			_complete_quest(quest_id)
		else:
			_active[quest_id] = next_step
	return true


func get_quest_definition(quest_id: StringName) -> QuestResource:
	var v = _quest_defs.get(quest_id)
	return v as QuestResource


func register_quest_definition(def: QuestResource) -> bool:
	if def == null:
		return false
	if String(def.id).is_empty():
		return false
	_quest_defs[def.id] = def
	return true


func reset_for_new_game() -> void:
	_active.clear()
	_completed.clear()


func capture_state() -> QuestSave:
	var save := QuestSave.new()
	save.active_quests = _active.duplicate(true)
	save.completed_quests = PackedStringArray()
	for k in _completed.keys():
		save.completed_quests.append(String(k))
	return save


func hydrate_state(save: QuestSave) -> void:
	if save == null:
		return
	_active.clear()
	_completed.clear()

	# Active quests
	if save.active_quests is Dictionary:
		for k in (save.active_quests as Dictionary).keys():
			var quest_id := StringName(String(k))
			var step_v = (save.active_quests as Dictionary)[k]
			var step_i := 0
			if step_v is int:
				step_i = int(step_v)
			elif step_v is float:
				step_i = int(step_v)
			if String(quest_id).is_empty():
				continue
			_active[quest_id] = max(0, step_i)

	# Completed quests (set semantics)
	for s in save.completed_quests:
		var quest_id := StringName(String(s))
		if String(quest_id).is_empty():
			continue
		_completed[quest_id] = true


#endregion

#region Internals


func _complete_quest(quest_id: StringName) -> void:
	_active.erase(quest_id)
	_completed[quest_id] = true
	if EventBus != null and "quest_completed" in EventBus:
		EventBus.quest_completed.emit(quest_id)


func _load_quest_definitions() -> void:
	_quest_defs.clear()
	if not DirAccess.dir_exists_absolute(_QUESTLINES_DIR):
		return
	var da := DirAccess.open(_QUESTLINES_DIR)
	if da == null:
		return
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if not da.current_is_dir() and entry.ends_with(".tres"):
			var path := "%s/%s" % [_QUESTLINES_DIR, entry]
			var res := load(path)
			if res is QuestResource:
				register_quest_definition(res as QuestResource)
		entry = da.get_next()
	da.list_dir_end()

#endregion
