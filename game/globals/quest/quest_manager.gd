extends Node

## QuestManager
## - Owns runtime quest state (active + completed)
## - Emits EventBus signals when state changes
## - Does NOT write Dialogic variables directly (DialogueManager owns that sync rule)

const _QUESTLINES_DIR := "res://game/data/quests"
const _MONEY_ICON: Texture2D = preload("res://assets/icons/money.png")
const _HEART_ICON_ATLAS: Texture2D = preload("res://assets/icons/heart.png")
const _HEART_ICON_FULL_REGION := Rect2i(0, 0, 16, 16)

var _heart_icon_full: Texture2D = null

var _quest_defs: Dictionary[StringName, QuestResource] = {}  # StringName -> QuestResource
var _active: Dictionary[StringName, int] = {}  # StringName -> int (current step index, 0-based)
var _completed: Dictionary[StringName, bool] = {}  # StringName -> bool (set semantics)
# quest_id -> Dictionary(step_idx:int -> progress:int)
var _objective_progress: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_quest_definitions()
	if EventBus != null and "quest_event" in EventBus:
		if not EventBus.quest_event.is_connected(_on_quest_event):
			EventBus.quest_event.connect(_on_quest_event)


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


## Returns objective progress for the given quest step (0 if none recorded).
## Progress is only tracked for active quests; completed quests always return 0.
func get_objective_progress(quest_id: StringName, step_index: int) -> int:
	if String(quest_id).is_empty():
		return 0
	if step_index < 0:
		return 0
	var per_step: Dictionary = _objective_progress.get(quest_id, {})
	return maxi(0, int(per_step.get(step_index, 0)))


func start_new_quest(quest_id: StringName) -> bool:
	if String(quest_id).is_empty():
		return false
	if _active.has(quest_id) or _completed.has(quest_id):
		return false
	_active[quest_id] = 0
	_objective_progress[quest_id] = {0: 0}
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

		# Grant per-step rewards (best-effort).
		var def_for_rewards: QuestResource = get_quest_definition(quest_id)
		if (
			def_for_rewards != null
			and (completed_step >= 0 and completed_step < def_for_rewards.steps.size())
		):
			var st: QuestStep = def_for_rewards.steps[completed_step]
			if st != null and st.step_rewards != null and not st.step_rewards.is_empty():
				_grant_rewards(st.step_rewards)

		if EventBus != null and "quest_step_completed" in EventBus:
			EventBus.quest_step_completed.emit(quest_id, completed_step)

		var next_step := completed_step + 1
		var def: QuestResource = get_quest_definition(quest_id)
		if def != null and next_step >= def.steps.size():
			_complete_quest(quest_id)
		else:
			_active[quest_id] = next_step
			# Initialize progress for the next step.
			var prog: Dictionary = _objective_progress.get(quest_id, {})
			prog[next_step] = 0
			_objective_progress[quest_id] = prog
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
	_objective_progress.clear()


func start_unlocked_quests_on_new_game() -> void:
	# Start quests that are explicitly configured to start on new game.
	# Do NOT start chained quests here (those require unlock_from_quest).
	for v in _quest_defs.values():
		var def: QuestResource = v
		if def == null:
			continue
		if not def.unlock_at_game_start:
			continue
		if not String(def.unlock_from_quest).is_empty():
			continue
		if not def.auto_start_when_unlocked:
			continue
		start_new_quest(def.id)


# Back-compat: older callers (pre-unlock-system).
func start_starting_quests() -> void:
	start_unlocked_quests_on_new_game()


func capture_state() -> QuestSave:
	var save := QuestSave.new()
	save.active_quests = _active.duplicate(true)
	save.completed_quests = PackedStringArray()
	for k in _completed.keys():
		save.completed_quests.append(String(k))

	# Objective progress (quest_id -> { step_idx -> progress })
	var prog_out: Dictionary = {}
	for q in _objective_progress.keys():
		var quest_id := String(q)
		if quest_id.is_empty():
			continue
		var per_step: Dictionary = _objective_progress.get(q, {})
		if per_step == null or not (per_step is Dictionary):
			continue
		var step_out: Dictionary = {}
		for step_k in (per_step as Dictionary).keys():
			var step_i := 0
			if step_k is int:
				step_i = int(step_k)
			elif step_k is float:
				step_i = int(step_k)
			else:
				step_i = int(String(step_k).to_int())
			step_out[step_i] = int((per_step as Dictionary).get(step_k, 0))
		prog_out[quest_id] = step_out
	save.objective_progress = prog_out
	return save


func hydrate_state(save: QuestSave) -> void:
	if save == null:
		return
	_active.clear()
	_completed.clear()
	_objective_progress.clear()

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
			_objective_progress[quest_id] = {int(_active[quest_id]): 0}

	# Completed quests (set semantics)
	for s in save.completed_quests:
		var quest_id := StringName(String(s))
		if String(quest_id).is_empty():
			continue
		_completed[quest_id] = true

	# Objective progress (optional, v2+)
	if "objective_progress" in save and save.objective_progress is Dictionary:
		for k in (save.objective_progress as Dictionary).keys():
			var quest_id := StringName(String(k))
			if String(quest_id).is_empty():
				continue
			var per_step_v: Variant = (save.objective_progress as Dictionary)[k]
			if not (per_step_v is Dictionary):
				continue
			var per_step_in := per_step_v as Dictionary
			var per_step_out: Dictionary = {}
			for step_k in per_step_in.keys():
				var step_i := 0
				if step_k is int:
					step_i = int(step_k)
				elif step_k is float:
					step_i = int(step_k)
				else:
					step_i = int(String(step_k).to_int())
				var pv: Variant = per_step_in[step_k]
				var pi := 0
				if pv is int:
					pi = int(pv)
				elif pv is float:
					pi = int(pv)
				per_step_out[step_i] = maxi(0, pi)
			_objective_progress[quest_id] = per_step_out

	# Ensure every active quest has progress initialized for its current step.
	for q in _active.keys():
		var quest_id := q as StringName
		if String(quest_id).is_empty():
			continue
		var step_idx := int(_active[quest_id])
		var per_step: Dictionary = _objective_progress.get(quest_id, {})
		if not per_step.has(step_idx):
			per_step[step_idx] = 0
		_objective_progress[quest_id] = per_step


#endregion

#region Internals


func _complete_quest(quest_id: StringName) -> void:
	# Grant completion rewards (best-effort) before emitting completion.
	var def_for_rewards = get_quest_definition(quest_id)
	if def_for_rewards != null:
		if (
			def_for_rewards.completion_rewards != null
			and not def_for_rewards.completion_rewards.is_empty()
		):
			_grant_rewards(def_for_rewards.completion_rewards)

	_active.erase(quest_id)
	_completed[quest_id] = true
	_objective_progress.erase(quest_id)
	if EventBus != null and "quest_completed" in EventBus:
		EventBus.quest_completed.emit(quest_id)
	_auto_start_unlocked_from(quest_id)


func _auto_start_unlocked_from(completed_quest_id: StringName) -> void:
	if String(completed_quest_id).is_empty():
		return
	for v in _quest_defs.values():
		var def: QuestResource = v
		if def == null:
			continue
		if def.unlock_from_quest != completed_quest_id:
			continue
		if not def.auto_start_when_unlocked:
			continue
		start_new_quest(def.id)


func _grant_rewards(rewards: Array) -> void:
	if rewards == null or rewards.is_empty():
		return
	var player := _get_player()
	if player == null:
		# If we can't resolve a player (headless/tests), skip silently.
		return
	# Grant first (so inventory/money actually updates), then present what was received.
	for r in rewards:
		if r == null:
			continue
		if r.has_method("grant"):
			r.call("grant", player)

	_present_granted_rewards(rewards)


func _present_granted_rewards(rewards: Array) -> void:
	# Keep headless tests deterministic (and avoid UI state transitions).
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		return
	if Runtime == null or Runtime.game_flow == null:
		return
	if not Runtime.game_flow.has_method("request_grant_reward"):
		return

	var rows: Array[GrantRewardRow] = []
	for r in rewards:
		if r == null:
			continue
		if r is QuestRewardItem:
			var ri := r as QuestRewardItem
			if ri.item != null and ri.item.icon != null:
				var title := "New item"
				if not ri.item.display_name.is_empty():
					title = "New item: %s" % ri.item.display_name
				var row := GrantRewardRow.new()
				row.kind = &"item"
				row.icon = ri.item.icon
				row.count = int(ri.count)
				row.title = title
				rows.append(row)
		elif r is QuestRewardMoney:
			var rr := r as QuestRewardMoney
			var amt := int(rr.amount)
			var title := "+%d money" % amt if amt >= 0 else "%d money" % amt
			var row := GrantRewardRow.new()
			row.kind = &"money"
			row.icon = _MONEY_ICON
			row.count = amt
			row.title = title
			rows.append(row)
		elif r is QuestRewardRelationship:
			# Use a heart icon; count is in whole hearts (best-effort).
			if _heart_icon_full == null:
				var at := AtlasTexture.new()
				at.atlas = _HEART_ICON_ATLAS
				at.region = _HEART_ICON_FULL_REGION
				_heart_icon_full = at
			var rr := r as QuestRewardRelationship
			var title := (
				"Relationship with %s %s"
				% [
					_capitalize_name(String(rr.npc_id)),
					_format_delta_units(int(rr.delta_units)),
				]
			)
			var row := GrantRewardRow.new()
			row.kind = &"relationship"
			row.icon = _heart_icon_full
			row.count = maxi(1, int(absi(int(rr.delta_units)) / 2.0))
			row.title = title
			row.npc_id = rr.npc_id
			row.delta_units = int(rr.delta_units)
			rows.append(row)

	if rows.is_empty():
		return

	Runtime.game_flow.call("request_grant_reward", rows, &"")


func _format_delta_units(delta_units: int) -> String:
	var s := "+" if delta_units >= 0 else "-"
	var absu := absi(int(delta_units))
	var whole := absu / 2.0
	var half := absu % 2
	if half == 0:
		return "%s%d\u2665" % [s, whole]
	if whole == 0:
		return "%s\u00bd\u2665" % s
	return "%s%d\u00bd\u2665" % [s, whole]


func _capitalize_name(raw: String) -> String:
	# Best-effort: turn "frieren" / "some_npc" into "Frieren" / "Some Npc".
	var s := raw.strip_edges().replace("_", " ")
	if s.is_empty():
		return raw
	var parts := s.split(" ", false)
	for i in range(parts.size()):
		var p := String(parts[i])
		if p.is_empty():
			continue
		parts[i] = p.left(1).to_upper() + p.substr(1)
	return " ".join(parts)


func _get_player() -> Node:
	# Prefer GameFlow's authoritative player lookup (groups-based).
	if Runtime != null and Runtime.game_flow != null and Runtime.game_flow.has_method("get_player"):
		return Runtime.game_flow.get_player()
	# Fallback: direct group scan.
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(Groups.PLAYER) as Node


func _on_quest_event(event_id: StringName, payload: Dictionary) -> void:
	# Event-driven objective tracking: update active quest step progress.
	if String(event_id).is_empty():
		return
	if _active.is_empty():
		return

	# Snapshot keys in case advancing/completing mutates `_active`.
	var quest_ids: Array = _active.keys()
	for q in quest_ids:
		var quest_id := q as StringName
		if String(quest_id).is_empty() or not _active.has(quest_id):
			continue
		var step_idx := int(_active[quest_id])
		var def: QuestResource = get_quest_definition(quest_id)
		if def == null or step_idx < 0 or step_idx >= def.steps.size():
			continue
		var step := def.steps[step_idx]
		if step == null or step.objective == null:
			continue

		var prog: Dictionary = _objective_progress.get(quest_id, {})
		var cur := int(prog.get(step_idx, 0))
		var next := int(step.objective.apply_event(event_id, payload, cur))
		if next != cur:
			prog[step_idx] = maxi(0, next)
			_objective_progress[quest_id] = prog

		if bool(step.objective.is_completed(int(prog.get(step_idx, 0)))):
			advance_quest(quest_id, 1)


func _load_quest_definitions() -> void:
	_quest_defs.clear()
	var loaded := _scan_quest_dir_recursive(_QUESTLINES_DIR)
	if loaded == 0:
		push_warning("QuestManager: no quest definitions found under %s" % _QUESTLINES_DIR)
		return

	# Validation (best-effort; authoring aid)
	var known_ids: Dictionary = {}
	for k in _quest_defs.keys():
		known_ids[k] = true
	for v in _quest_defs.values():
		var def: QuestResource = v
		if def == null:
			continue
		if def.has_method("validate"):
			var issues: PackedStringArray = def.validate(known_ids)
			for msg in issues:
				push_warning("Quest '%s': %s" % [String(def.id), String(msg)])


func _scan_quest_dir_recursive(dir_path: String) -> int:
	# NOTE: `DirAccess.dir_exists_absolute()` is for OS paths (e.g. C:/...), not `res://`.
	# `DirAccess.open("res://...")` returns null if the directory doesn't exist.
	var da := DirAccess.open(dir_path)
	if da == null:
		return 0

	var loaded := 0
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		# Skip dot entries and common noise.
		if entry == "." or entry == ".." or entry.begins_with("."):
			entry = da.get_next()
			continue

		if da.current_is_dir():
			loaded += _scan_quest_dir_recursive("%s/%s" % [dir_path, entry])
		elif entry.ends_with(".tres"):
			var path := "%s/%s" % [dir_path, entry]
			var res := load(path)
			if res is QuestResource:
				if register_quest_definition(res as QuestResource):
					loaded += 1
		entry = da.get_next()
	da.list_dir_end()
	return loaded

#endregion
