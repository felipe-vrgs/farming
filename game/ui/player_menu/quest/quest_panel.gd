@tool
class_name QuestPanel
extends MarginContainer

@export_group("Preview (Editor)")
## Preview by QuestResource (editor-friendly: shows title + step text).
@export var preview_active_quest_defs: Array[QuestResource] = []:
	set(v):
		preview_active_quest_defs = [] if v == null else v
		_apply_preview()
@export var preview_completed_quest_defs: Array[QuestResource] = []:
	set(v):
		preview_completed_quest_defs = [] if v == null else v
		_apply_preview()

@onready var active_list: ItemList = %ActiveList
@onready var completed_list: ItemList = %CompletedList
@onready var title_label: Label = %QuestTitle
@onready var step_label: Label = %QuestStep
@onready var status_label: Label = %QuestStatus
@onready var objectives_list: ItemList = %QuestObjectivesList
@onready var rewards_list: ItemList = %QuestRewardsList

var _active_ids: Array[StringName] = []
var _completed_ids: Array[StringName] = []
var _preview_defs_by_id: Dictionary = {}  # StringName -> QuestResource
var _current_quest_id: StringName = &""
var _current_is_active: bool = false
var _item_cache: Dictionary = {}  # StringName -> ItemData (or null)


func _ready() -> void:
	# UI must run while SceneTree is paused (PlayerMenu state).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if active_list != null:
		active_list.item_selected.connect(_on_active_selected)
	if completed_list != null:
		completed_list.item_selected.connect(_on_completed_selected)

	# In editor we may not have runtime autoloads/events; use preview instead.
	if not Engine.is_editor_hint() and EventBus != null:
		if not EventBus.quest_started.is_connected(_on_quest_changed):
			EventBus.quest_started.connect(_on_quest_changed)
		if not EventBus.quest_step_completed.is_connected(_on_quest_changed_step):
			EventBus.quest_step_completed.connect(_on_quest_changed_step)
		if not EventBus.quest_completed.is_connected(_on_quest_changed):
			EventBus.quest_completed.connect(_on_quest_changed)
		# Objective progress can change without completing the step.
		if not EventBus.quest_event.is_connected(_on_quest_event):
			EventBus.quest_event.connect(_on_quest_event)

	refresh()
	_apply_preview()


func _exit_tree() -> void:
	# Avoid callbacks firing after this panel is removed (e.g., during tests/state swaps).
	if EventBus == null:
		return
	if "quest_started" in EventBus and EventBus.quest_started.is_connected(_on_quest_changed):
		EventBus.quest_started.disconnect(_on_quest_changed)
	if (
		"quest_step_completed" in EventBus
		and EventBus.quest_step_completed.is_connected(_on_quest_changed_step)
	):
		EventBus.quest_step_completed.disconnect(_on_quest_changed_step)
	if "quest_completed" in EventBus and EventBus.quest_completed.is_connected(_on_quest_changed):
		EventBus.quest_completed.disconnect(_on_quest_changed)
	if "quest_event" in EventBus and EventBus.quest_event.is_connected(_on_quest_event):
		EventBus.quest_event.disconnect(_on_quest_event)


func rebind() -> void:
	refresh()


func _apply_preview() -> void:
	if not Engine.is_editor_hint():
		return
	# Editor preview: show a stable layout without requiring QuestManager/EventBus.
	_active_ids.clear()
	_completed_ids.clear()
	_preview_defs_by_id.clear()

	for d in preview_active_quest_defs:
		if d == null:
			continue
		var qid := d.id
		if String(qid).is_empty():
			continue
		_preview_defs_by_id[qid] = d
		_active_ids.append(qid)

	for d in preview_completed_quest_defs:
		if d == null:
			continue
		var qid := d.id
		if String(qid).is_empty():
			continue
		_preview_defs_by_id[qid] = d
		_completed_ids.append(qid)
	_refresh_lists_from_ids()


func refresh() -> void:
	_active_ids.clear()
	_completed_ids.clear()
	if active_list != null:
		active_list.clear()
	if completed_list != null:
		completed_list.clear()

	if Engine.is_editor_hint():
		_refresh_lists_from_ids()
		return

	if QuestManager != null:
		_active_ids = QuestManager.list_active_quests()
		_completed_ids = QuestManager.list_completed_quests()

	_refresh_lists_from_ids()


func _refresh_lists_from_ids() -> void:
	if active_list != null:
		active_list.clear()
	if completed_list != null:
		completed_list.clear()

	for quest_id in _active_ids:
		_add_quest_item(active_list, quest_id, true)
	for quest_id in _completed_ids:
		_add_quest_item(completed_list, quest_id, false)

	# Prefer keeping existing selection, otherwise select first active quest.
	if (
		active_list != null
		and active_list.get_selected_items().is_empty()
		and active_list.item_count > 0
	):
		active_list.select(0)
		_show_quest(_active_ids[0], true)
		return

	# If no active quests, show placeholder.
	if _active_ids.is_empty():
		_clear_details("No active quests.", "", "", [], [])


func _add_quest_item(list: ItemList, quest_id: StringName, is_active: bool) -> void:
	if list == null:
		return
	var n := String(quest_id)
	var def: QuestResource = null
	if Engine.is_editor_hint():
		def = _preview_defs_by_id.get(quest_id) as QuestResource
	else:
		if QuestManager != null:
			def = QuestManager.get_quest_definition(quest_id)
	if def != null and not def.title.is_empty():
		n = def.title
	var idx := list.add_item(n)
	list.set_item_metadata(idx, {"quest_id": String(quest_id), "active": is_active})


func _show_quest(quest_id: StringName, is_active: bool) -> void:
	_current_quest_id = quest_id
	_current_is_active = is_active

	if Engine.is_editor_hint():
		var tool_def: QuestResource = _preview_defs_by_id.get(quest_id) as QuestResource
		var t := String(quest_id)
		if tool_def != null and not tool_def.title.is_empty():
			t = tool_def.title
		var s := "Active" if is_active else "Completed"
		var st := ""
		var preview_objective_rows: Array[Dictionary] = []
		var preview_reward_rows: Array[Dictionary] = []
		if tool_def != null and tool_def.steps.size() > 0 and tool_def.steps[0] != null:
			var preview_step: QuestStep = tool_def.steps[0]
			st = preview_step.description
			if st.is_empty() and preview_step.objective != null:
				st = String(preview_step.objective.describe())
			preview_objective_rows = _build_objective_rows_for_step(tool_def, 0, 0, true)
			preview_reward_rows = _build_reward_rows_for_step(tool_def, 0)
		else:
			st = "Preview step text"
			preview_objective_rows = [_row_text("None")]
			preview_reward_rows = [_row_text("None")]
		_set_details(t, s, st, preview_objective_rows, preview_reward_rows)
		return

	if QuestManager == null:
		_clear_details("QuestManager unavailable.", "", "", [], [])
		return

	var def: QuestResource = QuestManager.get_quest_definition(quest_id)
	var title := String(quest_id)
	if def != null and not def.title.is_empty():
		title = def.title

	var status := "Active" if is_active else "Completed"
	var step_text := ""
	var objective_rows: Array[Dictionary] = []
	var reward_rows: Array[Dictionary] = []

	if is_active:
		var step_idx := QuestManager.get_active_quest_step(quest_id)
		if def != null and step_idx >= 0 and step_idx < def.steps.size():
			var st: QuestStep = def.steps[step_idx]
			step_text = st.description
			if step_text.is_empty() and st.objective != null:
				step_text = String(st.objective.describe())
			var progress := 0
			if QuestManager != null and QuestManager.has_method("get_objective_progress"):
				progress = int(QuestManager.get_objective_progress(quest_id, step_idx))
			objective_rows = _build_objective_rows_for_step(def, step_idx, progress, false)
			reward_rows = _build_reward_rows_for_step(def, step_idx)
		else:
			step_text = "Step %d" % step_idx
			objective_rows = [_row_text("None")]
			reward_rows = [_row_text("None")]
	else:
		if def != null and def.steps.size() > 0:
			step_text = "Completed (%d steps)" % def.steps.size()
			objective_rows = _build_objective_rows_for_completed(def)
			reward_rows = _build_reward_rows_for_completed(def)
		else:
			step_text = "Completed"
			objective_rows = [_row_text("None")]
			reward_rows = [_row_text("None")]

	_set_details(title, status, step_text, objective_rows, reward_rows)


func _set_details(
	title: String,
	status: String,
	step: String,
	objectives: Array[Dictionary] = [],
	rewards: Array[Dictionary] = []
) -> void:
	if title_label != null:
		title_label.text = title
	if status_label != null:
		status_label.text = status
	if step_label != null:
		step_label.text = step
	_set_rows(objectives_list, objectives)
	_set_rows(rewards_list, rewards)


func _clear_details(
	title: String,
	status: String,
	step: String,
	objectives: Array[Dictionary],
	rewards: Array[Dictionary]
) -> void:
	_set_details(title, status, step, objectives, rewards)


func _build_objective_rows_for_step(
	def: QuestResource, step_idx: int, progress: int, is_preview: bool
) -> Array[Dictionary]:
	if def == null or step_idx < 0 or step_idx >= def.steps.size():
		return [_row_text("None")]
	var step: QuestStep = def.steps[step_idx]
	if step == null:
		return [_row_text("None")]

	# Single objective per step (for now).
	if step.objective != null:
		var target := maxi(1, int(step.objective.target_count))
		var p := maxi(0, int(progress))
		var p_shown := clampi(p, 0, target)
		if is_preview:
			p_shown = clampi(int(progress), 0, target)

		var label := String(step.objective.describe())
		if label.is_empty():
			label = "Objective"

		var icon: Texture2D = null
		if step.objective is QuestObjectiveItemCount:
			var o := step.objective as QuestObjectiveItemCount
			icon = _resolve_item_icon(o.item_id)
			if icon != null:
				var item := _resolve_item_data(o.item_id)
				if item != null and not item.display_name.is_empty():
					# Replace raw item_id in the label with display name, best-effort.
					label = label.replace(String(o.item_id), item.display_name)

		return [_row_text("%s (%d/%d)" % [label, int(p_shown), int(target)], icon)]

	# If no objective resource is attached, fall back to step description.
	var desc := String(step.description)
	if desc.is_empty():
		desc = "Objective"
	return [_row_text(desc)]


func _build_objective_rows_for_completed(def: QuestResource) -> Array[Dictionary]:
	if def == null or def.steps == null or def.steps.is_empty():
		return [_row_text("None")]
	var rows: Array[Dictionary] = []
	for i in range(def.steps.size()):
		var st: QuestStep = def.steps[i]
		if st == null:
			continue
		if st.objective != null:
			var label := String(st.objective.describe())
			if label.is_empty():
				label = "Objective"
			var icon: Texture2D = null
			if st.objective is QuestObjectiveItemCount:
				var o := st.objective as QuestObjectiveItemCount
				icon = _resolve_item_icon(o.item_id)
				if icon != null:
					var item := _resolve_item_data(o.item_id)
					if item != null and not item.display_name.is_empty():
						label = label.replace(String(o.item_id), item.display_name)
			rows.append(_row_text(label, icon))
		else:
			var desc := String(st.description)
			if desc.is_empty():
				desc = "Objective"
			rows.append(_row_text(desc))
	if rows.is_empty():
		return [_row_text("None")]
	return rows


func _build_reward_rows_for_step(def: QuestResource, step_idx: int) -> Array[Dictionary]:
	if def == null:
		return [_row_text("None")]
	var rows: Array[Dictionary] = []

	# Step rewards (granted on completing the current step).
	if step_idx >= 0 and step_idx < def.steps.size():
		var st: QuestStep = def.steps[step_idx]
		if st != null and st.step_rewards != null and not st.step_rewards.is_empty():
			rows.append(_row_header("On step complete:"))
			rows.append_array(_build_reward_rows_list(st.step_rewards))

	# Quest completion rewards (granted after final step).
	if def.completion_rewards != null and not def.completion_rewards.is_empty():
		if not rows.is_empty():
			rows.append(_row_spacer())
		rows.append(_row_header("On quest complete:"))
		rows.append_array(_build_reward_rows_list(def.completion_rewards))

	if rows.is_empty():
		return [_row_text("None")]
	return rows


func _build_reward_rows_for_completed(def: QuestResource) -> Array[Dictionary]:
	if def == null:
		return [_row_text("None")]
	# When completed, completion rewards have already been granted; still show them for reference.
	if def.completion_rewards == null or def.completion_rewards.is_empty():
		return [_row_text("None")]
	return _build_reward_rows_list(def.completion_rewards)


func _build_reward_rows_list(rewards: Array) -> Array[Dictionary]:
	if rewards == null or rewards.is_empty():
		return [_row_text("None")]
	var rows: Array[Dictionary] = []
	for r in rewards:
		if r == null:
			continue
		# Best-effort icon support.
		var icon: Texture2D = null
		var d := ""
		if r is QuestRewardItem:
			var ri := r as QuestRewardItem
			if ri.item != null:
				icon = ri.item.icon
				d = "%s x%d" % [ri.item.display_name, int(ri.count)]
		if d.is_empty() and r.has_method("describe"):
			d = String(r.call("describe"))
		if d.is_empty():
			d = "Reward"
		rows.append(_row_text(d, icon))
	if rows.is_empty():
		return [_row_text("None")]
	return rows


func _set_rows(list: ItemList, rows: Array[Dictionary]) -> void:
	# NOTE: We use ItemList here (icons + no node churn).
	if list == null:
		return
	list.clear()
	for row in rows:
		var is_spacer := bool(row.get("spacer", false))
		var is_header := bool(row.get("header", false))
		var text := "" if is_spacer else String(row.get("text", ""))
		var icon: Texture2D = row.get("icon") as Texture2D
		var idx := list.add_item(text, icon)
		# These lists are read-only; prevent selection/focus issues.
		list.set_item_selectable(idx, false)
		if is_header:
			# Best-effort visual: treat as a category row (no icon).
			list.set_item_icon(idx, null)
		if is_spacer:
			list.set_item_disabled(idx, true)

	# Let the outer ScrollContainer handle overflow: expand the list height to fit items.
	var count := list.item_count
	if count <= 0:
		list.custom_minimum_size = Vector2(list.custom_minimum_size.x, 0)
		return
	# Approximate per-row height (theme font size is tiny in this UI).
	var font_size := 0
	if list.has_theme_font_size_override(&"font_size"):
		font_size = int(list.get_theme_font_size(&"font_size"))
	else:
		font_size = int(list.get_theme_font_size(&"font_size", &"ItemList"))
	var row_h := maxi(14, font_size + 10)
	list.custom_minimum_size = Vector2(list.custom_minimum_size.x, count * row_h)


func _row_text(text: String, icon: Texture2D = null) -> Dictionary:
	return {"text": text, "icon": icon}


func _row_header(text: String) -> Dictionary:
	return {"text": text, "header": true}


func _row_spacer() -> Dictionary:
	return {"spacer": true}


func _resolve_item_icon(item_id: StringName) -> Texture2D:
	var item := _resolve_item_data(item_id)
	if item == null:
		return null
	return item.icon


func _resolve_item_data(item_id: StringName) -> ItemData:
	if String(item_id).is_empty():
		return null
	if _item_cache.has(item_id):
		return _item_cache[item_id] as ItemData

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
	_item_cache[item_id] = resolved
	return resolved


func _on_active_selected(index: int) -> void:
	if index < 0 or index >= _active_ids.size():
		return
	# Ensure switching back from Completed works even if the active quest was already selected
	# (ItemList won't emit `item_selected` when selecting an already-selected item).
	if completed_list != null:
		completed_list.deselect_all()
	_show_quest(_active_ids[index], true)


func _on_completed_selected(index: int) -> void:
	if index < 0 or index >= _completed_ids.size():
		return
	# Mirror active selection behavior.
	if active_list != null:
		active_list.deselect_all()
	_show_quest(_completed_ids[index], false)


func _on_quest_changed(_quest_id: StringName) -> void:
	refresh()


func _on_quest_changed_step(_quest_id: StringName, _step_index: int) -> void:
	refresh()


func _on_quest_event(_event_id: StringName, _payload: Dictionary) -> void:
	# If the user has the player menu open, refresh the details to reflect progress updates.
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if not _current_is_active:
		return
	if String(_current_quest_id).is_empty():
		return
	_show_quest(_current_quest_id, _current_is_active)
