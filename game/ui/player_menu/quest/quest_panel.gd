@tool
class_name QuestPanel
extends MarginContainer

const _REWARD_FONT_SIZE := 4

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

@onready var list: ItemList = %List
@onready var title_label: Label = %QuestTitle
@onready var step_label: Label = %QuestStep
@onready var objectives_list: ItemList = %QuestObjectivesList
@onready var rewards_list: VBoxContainer = %QuestRewardsList

enum QuestKind { ACTIVE, PENDING, COMPLETED }

var _active_ids: Array[StringName] = []
var _completed_ids: Array[StringName] = []
var _preview_defs_by_id: Dictionary = {}  # StringName -> QuestResource
var _entries: Array[Dictionary] = []  # idx-aligned: { quest_id:StringName, kind:int, step_idx:int }
var _current_quest_id: StringName = &""
var _current_is_active: bool = false
var _current_kind: int = QuestKind.PENDING


func _ready() -> void:
	# UI must run while SceneTree is paused (PlayerMenu state).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if list != null:
		list.item_selected.connect(_on_list_selected)

	# Headless tests often manipulate `_active_ids` / `_completed_ids` directly and should not be
	# affected by live EventBus quest events from other systems/tests.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		refresh()
		_apply_preview()
		return

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
	if list != null:
		list.clear()
	_entries.clear()

	# In test mode, keep injected ids stable and only rebuild the UI list.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		_refresh_lists_from_ids()
		return

	if Engine.is_editor_hint():
		_refresh_lists_from_ids()
		return

	if QuestManager != null:
		_active_ids = QuestManager.list_active_quests()
		_completed_ids = QuestManager.list_completed_quests()

	_refresh_lists_from_ids()


func _refresh_lists_from_ids() -> void:
	if list != null:
		list.clear()
	_entries.clear()

	var rows: Array[Dictionary] = []

	# Editor preview: only show the configured preview defs.
	if Engine.is_editor_hint():
		for quest_id in _active_ids:
			rows.append({"quest_id": quest_id, "kind": QuestKind.ACTIVE, "step_idx": 0})
		for quest_id in _completed_ids:
			rows.append({"quest_id": quest_id, "kind": QuestKind.COMPLETED, "step_idx": -1})
	elif _should_use_injected_ids_override():
		# Some headless tests inject `_active_ids/_completed_ids` with synthetic ids that are
		# not known by QuestManager. In that case, prefer the injected ids so tests remain
		# deterministic and independent from quest unlock rules.
		for quest_id in _active_ids:
			# Treat as "active with progress" for sort grouping.
			rows.append({"quest_id": quest_id, "kind": QuestKind.ACTIVE, "step_idx": 1})
		for quest_id in _completed_ids:
			rows.append({"quest_id": quest_id, "kind": QuestKind.COMPLETED, "step_idx": -1})
	else:
		# Runtime: show all unlocked quests, sorted by:
		# Active (step_idx > 0), Pending (step_idx == 0 OR not accepted), Completed.
		var ids: Array[StringName] = []
		if QuestManager != null:
			ids = QuestManager.list_all_quest_ids()
		else:
			# Fallback: at least show what we know about.
			ids.append_array(_active_ids)
			for q in _completed_ids:
				if not ids.has(q):
					ids.append(q)

		var completed_set: Dictionary = {}
		for q in _completed_ids:
			completed_set[q] = true

		for quest_id in ids:
			if String(quest_id).is_empty():
				continue

			var is_started := _active_ids.has(quest_id)
			var is_completed := bool(completed_set.get(quest_id, false))
			var is_unlocked := true
			if QuestManager != null:
				is_unlocked = bool(QuestManager.is_quest_unlocked(quest_id))
			# Only show unlocked quests (plus any started/completed ones as a safety net).
			if not is_unlocked and not is_started and not is_completed:
				continue

			var kind := QuestKind.PENDING
			var step_idx := -1
			if is_completed:
				kind = QuestKind.COMPLETED
			elif is_started:
				kind = QuestKind.ACTIVE
				if QuestManager != null:
					step_idx = int(QuestManager.get_active_quest_step(quest_id))
			rows.append({"quest_id": quest_id, "kind": kind, "step_idx": step_idx})

	# Sort rows per UX rule.
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_id: StringName = a.get("quest_id", &"")
			var b_id: StringName = b.get("quest_id", &"")
			var a_kind := int(a.get("kind", QuestKind.PENDING))
			var b_kind := int(b.get("kind", QuestKind.PENDING))
			var a_step := int(a.get("step_idx", -1))
			var b_step := int(b.get("step_idx", -1))

			var a_rank := 1
			if a_kind == QuestKind.COMPLETED:
				a_rank = 2
			elif a_kind == QuestKind.ACTIVE and a_step > 0:
				a_rank = 0
			var b_rank := 1
			if b_kind == QuestKind.COMPLETED:
				b_rank = 2
			elif b_kind == QuestKind.ACTIVE and b_step > 0:
				b_rank = 0
			if a_rank != b_rank:
				return a_rank < b_rank

			var a_title := _quest_title_for(a_id)
			var b_title := _quest_title_for(b_id)
			if a_title != b_title:
				return a_title < b_title
			return String(a_id) < String(b_id)
	)

	for row in rows:
		_add_quest_item(list, row)

	# Prefer keeping existing selection, otherwise select first quest.
	var selected_idx := -1
	if list != null:
		for i in range(list.item_count):
			var md: Variant = list.get_item_metadata(i)
			if md is Dictionary:
				var qid := StringName(String((md as Dictionary).get("quest_id", "")))
				if qid == _current_quest_id:
					selected_idx = i
					break

	if list == null or list.item_count <= 0:
		_clear_details("No quests.", "", [], [])
		return

	if selected_idx < 0:
		selected_idx = 0
	list.select(selected_idx)
	_show_selected_index(selected_idx)


func _quest_title_for(quest_id: StringName) -> String:
	var def: QuestResource = null
	if Engine.is_editor_hint():
		def = _preview_defs_by_id.get(quest_id) as QuestResource
	elif QuestManager != null:
		def = QuestManager.get_quest_definition(quest_id)
	if def != null and not def.title.is_empty():
		return def.title
	return String(quest_id)


func _should_use_injected_ids_override() -> bool:
	# If QuestManager isn't available, the only meaningful source of ids is
	# `_active_ids/_completed_ids`.
	if QuestManager == null:
		return not (_active_ids.is_empty() and _completed_ids.is_empty())

	# If the injected ids are not active/completed in QuestManager AND have no definition,
	# treat them as synthetic test data and prefer them over live QuestManager enumeration.
	for q in _active_ids:
		if QuestManager.is_quest_active(q):
			continue
		if QuestManager.get_quest_definition(q) != null:
			continue
		return true

	for q in _completed_ids:
		if QuestManager.is_quest_completed(q):
			continue
		if QuestManager.get_quest_definition(q) != null:
			continue
		return true

	return false


func _add_quest_item(target_list: ItemList, row: Dictionary) -> void:
	if target_list == null or row == null:
		return
	var quest_id: StringName = row.get("quest_id", &"")
	var kind := int(row.get("kind", QuestKind.PENDING))
	var step_idx := int(row.get("step_idx", -1))
	var n := _quest_title_for(quest_id)
	if kind == QuestKind.COMPLETED:
		n = "✓ " + n
	var idx := target_list.add_item(n)
	(
		target_list
		. set_item_metadata(
			idx,
			{
				"quest_id": String(quest_id),
				"kind": kind,
				"step_idx": step_idx,
			}
		)
	)
	_entries.append({"quest_id": quest_id, "kind": kind, "step_idx": step_idx})


func _show_selected_index(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var row := _entries[index]
	_show_quest(row.get("quest_id", &""), int(row.get("kind", QuestKind.PENDING)))


func _show_quest(quest_id: StringName, kind: int) -> void:
	_current_quest_id = quest_id
	_current_kind = kind
	_current_is_active = (kind == QuestKind.ACTIVE)

	if Engine.is_editor_hint():
		var tool_def: QuestResource = _preview_defs_by_id.get(quest_id) as QuestResource
		var t := String(quest_id)
		if tool_def != null and not tool_def.title.is_empty():
			t = tool_def.title
		var st := ""
		var preview_objective_rows: Array[Dictionary] = []
		var preview_reward_rows: Array = []
		if tool_def != null and tool_def.steps.size() > 0 and tool_def.steps[0] != null:
			var preview_step: QuestStep = tool_def.steps[0]
			st = preview_step.description
			if st.is_empty() and preview_step.objective != null:
				st = _safe_describe_objective(preview_step.objective, "Objective")
			preview_objective_rows = _build_objective_rows_for_active(tool_def, 0, 0, true)
			preview_reward_rows = _build_reward_rows_for_step(tool_def, 0)
		else:
			st = "Preview step text"
			preview_objective_rows = [_row_text("None")]
			preview_reward_rows = [_row_text("None")]
		_set_details(t, st, preview_objective_rows, preview_reward_rows)
		return

	if QuestManager == null:
		_clear_details("QuestManager unavailable.", "", [], [])
		return

	var def: QuestResource = QuestManager.get_quest_definition(quest_id)
	var title := String(quest_id)
	if def != null and not def.title.is_empty():
		title = def.title

	var step_text := ""
	var objective_rows: Array[Dictionary] = []
	var reward_rows: Array = []

	if kind == QuestKind.ACTIVE:
		var step_idx := QuestManager.get_active_quest_step(quest_id)
		if def != null and step_idx >= 0 and step_idx < def.steps.size():
			var st: QuestStep = def.steps[step_idx]
			step_text = st.description
			if step_text.is_empty() and st.objective != null:
				step_text = _safe_describe_objective(st.objective, "Objective")
			var progress := 0
			if QuestManager != null and QuestManager.has_method("get_objective_progress"):
				progress = int(QuestManager.get_objective_progress(quest_id, step_idx))
			objective_rows = _build_objective_rows_for_active(def, step_idx, progress, false)
			reward_rows = _build_reward_rows_for_step(def, step_idx)
		else:
			step_text = "Step %d" % step_idx
			objective_rows = [_row_text("None")]
			reward_rows = [_row_text("None")]
	elif kind == QuestKind.COMPLETED:
		if def != null and def.steps.size() > 0:
			step_text = "Completed (%d steps)" % def.steps.size()
			objective_rows = _build_objective_rows_for_completed(def)
			reward_rows = _build_reward_rows_for_completed(def)
		else:
			step_text = "Completed"
			objective_rows = [_row_text("None")]
			reward_rows = [_row_text("None")]
	else:
		# Pending / not accepted yet: show the first step as a preview (best-effort).
		if def == null:
			_clear_details(title, "Pending", [_row_text("None")], [_row_text("None")])
			return

		if not def.description.is_empty():
			step_text = def.description

		var step_idx0 := 0
		if def.steps != null and not def.steps.is_empty() and def.steps[0] != null:
			var st0: QuestStep = def.steps[0]
			if step_text.is_empty():
				step_text = st0.description
				if step_text.is_empty() and st0.objective != null:
					step_text = _safe_describe_objective(st0.objective, "Objective")
			objective_rows = [_row_header("First step:")]
			objective_rows.append_array(_build_objective_rows_for_step(def, step_idx0, 0, false))
			reward_rows = _build_reward_rows_for_step(def, step_idx0)
		else:
			if step_text.is_empty():
				step_text = "Pending"
			objective_rows = [_row_text("None")]
			reward_rows = [_row_text("None")]

	_set_details(title, step_text, objective_rows, reward_rows)


func _set_details(
	title: String, step: String, objectives: Array[Dictionary] = [], rewards: Array = []
) -> void:
	if title_label != null:
		title_label.text = title
	if step_label != null:
		step_label.text = step
	_set_rows(objectives_list, objectives)
	_set_reward_rows(rewards_list, rewards)


func _clear_details(
	title: String, step: String, objectives: Array[Dictionary], rewards: Array
) -> void:
	_set_details(title, step, objectives, rewards)


func _safe_describe_objective(obj: Resource, fallback: String = "") -> String:
	# In the editor (tool mode), quest resources can contain placeholder objective
	# instances (script not loaded). Calling methods on those errors.
	if obj == null:
		return fallback
	if Engine.is_editor_hint():
		var scr = obj.get_script()
		# Placeholder instance, or a non-tool script loaded in a tool script context.
		if scr == null:
			return fallback
		if scr is Script and not (scr as Script).is_tool():
			return fallback
	if obj.has_method("describe"):
		var s := String(obj.call("describe")).strip_edges()
		return s if not s.is_empty() else fallback
	return fallback


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
		var target := maxi(1, QuestUiHelper.safe_get_int(step.objective, &"target_count", 1))
		var p := maxi(0, int(progress))
		var p_shown := clampi(p, 0, target)
		if is_preview:
			p_shown = clampi(int(progress), 0, target)

		var label := _safe_describe_objective(step.objective, "Objective")

		var icon: Texture2D = null
		if step.objective is QuestObjectiveItemCount:
			var o := step.objective as QuestObjectiveItemCount
			var item := QuestUiHelper.resolve_item_data(o.item_id)
			if item != null:
				icon = item.icon
				if not item.display_name.is_empty():
					# Replace raw item_id in the label with display name, best-effort.
					label = label.replace(String(o.item_id), item.display_name)
		elif step.objective is QuestObjectiveTalk:
			var o2 := step.objective as QuestObjectiveTalk
			icon = QuestUiHelper.resolve_npc_icon(o2.npc_id)

		return [
			_row_text(
				"%s (%s)" % [label, QuestUiHelper.format_progress(int(p_shown), int(target))], icon
			)
		]

	# If no objective resource is attached, fall back to step description.
	var desc := String(step.description)
	if desc.is_empty():
		desc = "Objective"
	return [_row_text(desc)]


func _build_objective_rows_for_active(
	def: QuestResource, step_idx: int, progress: int, is_preview: bool
) -> Array[Dictionary]:
	if def == null or def.steps == null or def.steps.is_empty():
		return [_row_text("None")]
	if step_idx < 0 or step_idx >= def.steps.size():
		return [_row_text("None")]

	var rows: Array[Dictionary] = []

	# Completed steps (history).
	if step_idx > 0:
		rows.append(_row_header("Completed steps:"))
		for i in range(step_idx):
			var r := _build_objective_row_for_step(def, i, 0, false, "✓ ", is_preview)
			if not r.is_empty():
				rows.append(r)

	# Current step.
	rows.append(_row_header("Current step:"))
	var cur_row := _build_objective_row_for_step(def, step_idx, progress, true, "", is_preview)
	if not cur_row.is_empty():
		rows.append(cur_row)

	return rows if not rows.is_empty() else [_row_text("None")]


func _build_objective_row_for_step(
	def: QuestResource,
	step_idx: int,
	progress: int,
	show_progress: bool,
	prefix: String,
	is_preview: bool
) -> Dictionary:
	if def == null or step_idx < 0 or step_idx >= def.steps.size():
		return {}
	var step: QuestStep = def.steps[step_idx]
	if step == null:
		return {}

	var label := ""
	var icon: Texture2D = null

	if step.objective != null:
		label = _safe_describe_objective(step.objective, "Objective")

		if step.objective is QuestObjectiveItemCount:
			var o := step.objective as QuestObjectiveItemCount
			var item := QuestUiHelper.resolve_item_data(o.item_id)
			if item != null:
				icon = item.icon
				if not item.display_name.is_empty():
					label = label.replace(String(o.item_id), item.display_name)
		elif step.objective is QuestObjectiveTalk:
			var o2 := step.objective as QuestObjectiveTalk
			icon = QuestUiHelper.resolve_npc_icon(o2.npc_id)
	else:
		label = String(step.description)
		if label.is_empty():
			label = "Objective"

	if show_progress and step.objective != null:
		var target := maxi(1, QuestUiHelper.safe_get_int(step.objective, &"target_count", 1))
		var p := maxi(0, int(progress))
		var p_shown := clampi(p, 0, target)
		if is_preview:
			p_shown = clampi(int(progress), 0, target)
		label = "%s (%s)" % [label, QuestUiHelper.format_progress(int(p_shown), int(target))]

	return _row_text(prefix + label, icon)


func _build_objective_rows_for_completed(def: QuestResource) -> Array[Dictionary]:
	if def == null or def.steps == null or def.steps.is_empty():
		return [_row_text("None")]
	var rows: Array[Dictionary] = []
	for i in range(def.steps.size()):
		var st: QuestStep = def.steps[i]
		if st == null:
			continue
		if st.objective != null:
			var label := _safe_describe_objective(st.objective, "Objective")
			var icon: Texture2D = null
			if st.objective is QuestObjectiveItemCount:
				var o := st.objective as QuestObjectiveItemCount
				var item := QuestUiHelper.resolve_item_data(o.item_id)
				if item != null:
					icon = item.icon
					if not item.display_name.is_empty():
						label = label.replace(String(o.item_id), item.display_name)
			elif st.objective is QuestObjectiveTalk:
				var o2 := st.objective as QuestObjectiveTalk
				icon = QuestUiHelper.resolve_npc_icon(o2.npc_id)
			rows.append(_row_text(label, icon))
		else:
			var desc := String(st.description)
			if desc.is_empty():
				desc = "Objective"
			rows.append(_row_text(desc))
	if rows.is_empty():
		return [_row_text("None")]
	return rows


func _build_reward_rows_for_step(def: QuestResource, step_idx: int) -> Array:
	if def == null:
		return [_row_text("None")]
	var rows: Array = []

	# Step rewards (granted on completing the current step).
	if step_idx >= 0 and step_idx < def.steps.size():
		var st: QuestStep = def.steps[step_idx]
		if st != null and st.step_rewards != null and not st.step_rewards.is_empty():
			rows.append(_row_header("On step complete:"))
			var built := _build_reward_rows_list(st.step_rewards)
			if built.is_empty():
				rows.append(_row_text("None"))
			else:
				rows.append_array(built)

	# Quest completion rewards (granted after final step).
	if def.completion_rewards != null and not def.completion_rewards.is_empty():
		if not rows.is_empty():
			rows.append(_row_spacer())
		rows.append(_row_header("On quest complete:"))
		var built2 := _build_reward_rows_list(def.completion_rewards)
		if built2.is_empty():
			rows.append(_row_text("None"))
		else:
			rows.append_array(built2)

	if rows.is_empty():
		return [_row_text("None")]
	return rows


func _build_reward_rows_for_completed(def: QuestResource) -> Array:
	if def == null:
		return [_row_text("None")]
	# When completed, completion rewards have already been granted; still show them for reference.
	if def.completion_rewards == null or def.completion_rewards.is_empty():
		return [_row_text("None")]
	var built := _build_reward_rows_list(def.completion_rewards)
	return built if not built.is_empty() else [_row_text("None")]


func _build_reward_rows_list(rewards: Array) -> Array[QuestUiHelper.RewardDisplay]:
	return QuestUiHelper.build_reward_displays(rewards)


func _set_rows(target_list: ItemList, rows: Array[Dictionary]) -> void:
	# NOTE: We use ItemList here (icons + no node churn).
	if target_list == null:
		return
	target_list.clear()
	for row in rows:
		var is_spacer := bool(row.get("spacer", false))
		var is_header := bool(row.get("header", false))
		var text := "" if is_spacer else String(row.get("text", ""))
		var icon: Texture2D = row.get("icon") as Texture2D
		var idx := target_list.add_item(text, icon)
		# These lists are read-only; prevent selection/focus issues.
		target_list.set_item_selectable(idx, false)
		if is_header:
			# Best-effort visual: treat as a category row (no icon).
			target_list.set_item_icon(idx, null)
		if is_spacer:
			target_list.set_item_disabled(idx, true)

	# Let the outer ScrollContainer handle overflow: expand the list height to fit items.
	var count := target_list.item_count
	if count <= 0:
		target_list.custom_minimum_size = Vector2(target_list.custom_minimum_size.x, 0)
		return
	# Approximate per-row height (theme font size is tiny in this UI).
	var font_size := 0
	if target_list.has_theme_font_size_override(&"font_size"):
		font_size = int(target_list.get_theme_font_size(&"font_size"))
	else:
		font_size = int(target_list.get_theme_font_size(&"font_size", &"ItemList"))
	var row_h := maxi(14, font_size + 10)
	target_list.custom_minimum_size = Vector2(target_list.custom_minimum_size.x, count * row_h)


func _set_reward_rows(container: VBoxContainer, rows: Array) -> void:
	# Rewards need richer layout (relationship reward uses 2 icons), so we use real Controls.
	if container == null:
		return
	for c in container.get_children():
		c.queue_free()

	if rows == null or rows.is_empty():
		container.add_child(_make_reward_text_row("None"))
		return

	for row in rows:
		if row == null:
			continue

		if row is Dictionary:
			var d := row as Dictionary
			var is_spacer := bool(d.get("spacer", false))
			var is_header := bool(d.get("header", false))
			var text := "" if is_spacer else String(d.get("text", ""))
			var icon: Texture2D = d.get("icon") as Texture2D

			if is_spacer:
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(0, 4)
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				spacer.process_mode = Node.PROCESS_MODE_ALWAYS
				container.add_child(spacer)
				continue

			if is_header:
				var hdr := Label.new()
				hdr.text = text
				hdr.add_theme_font_size_override(&"font_size", _REWARD_FONT_SIZE)
				hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hdr.process_mode = Node.PROCESS_MODE_ALWAYS
				container.add_child(hdr)
				continue

			var row_ui := QuestDisplayRow.new()
			row_ui.font_size = _REWARD_FONT_SIZE
			row_ui.left_icon_size = Vector2(16, 16)
			row_ui.portrait_size = Vector2(24, 24)
			row_ui.row_alignment = BoxContainer.ALIGNMENT_BEGIN
			row_ui.setup_text_icon(text, icon)
			container.add_child(row_ui)
			continue

		if row is QuestUiHelper.RewardDisplay:
			var r := row as QuestUiHelper.RewardDisplay
			var row_ui := QuestDisplayRow.new()
			row_ui.font_size = _REWARD_FONT_SIZE
			row_ui.left_icon_size = Vector2(16, 16)
			row_ui.portrait_size = Vector2(24, 24)
			row_ui.row_alignment = BoxContainer.ALIGNMENT_BEGIN
			row_ui.setup_reward(r)
			container.add_child(row_ui)


func _make_reward_text_row(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override(&"font_size", _REWARD_FONT_SIZE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	return lbl


func _row_text(text: String, icon: Texture2D = null) -> Dictionary:
	return {"text": text, "icon": icon}


func _row_header(text: String) -> Dictionary:
	return {"text": text, "header": true}


func _row_spacer() -> Dictionary:
	return {"spacer": true}


func _on_list_selected(index: int) -> void:
	_show_selected_index(index)


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
