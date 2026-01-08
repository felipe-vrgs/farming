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

var _active_ids: Array[StringName] = []
var _completed_ids: Array[StringName] = []
var _preview_defs_by_id: Dictionary = {}  # StringName -> QuestResource


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

	refresh()
	_apply_preview()


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
		_clear_details("No active quests.", "", "")


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
	if Engine.is_editor_hint():
		var tool_def: QuestResource = _preview_defs_by_id.get(quest_id) as QuestResource
		var t := String(quest_id)
		if tool_def != null and not tool_def.title.is_empty():
			t = tool_def.title
		var s := "Active" if is_active else "Completed"
		var st := "Preview step text"
		if tool_def != null and tool_def.steps.size() > 0 and tool_def.steps[0] != null:
			st = tool_def.steps[0].description
		_set_details(t, s, st)
		return

	if QuestManager == null:
		_clear_details("QuestManager unavailable.", "", "")
		return

	var def: QuestResource = QuestManager.get_quest_definition(quest_id)
	var title := String(quest_id)
	if def != null and not def.title.is_empty():
		title = def.title

	var status := "Active" if is_active else "Completed"
	var step_text := ""

	if is_active:
		var step_idx := QuestManager.get_active_quest_step(quest_id)
		if def != null and step_idx >= 0 and step_idx < def.steps.size():
			step_text = def.steps[step_idx].description
		else:
			step_text = "Step %d" % step_idx
	else:
		if def != null and def.steps.size() > 0:
			step_text = "Completed (%d steps)" % def.steps.size()
		else:
			step_text = "Completed"

	_set_details(title, status, step_text)


func _set_details(title: String, status: String, step: String) -> void:
	if title_label != null:
		title_label.text = title
	if status_label != null:
		status_label.text = status
	if step_label != null:
		step_label.text = step


func _clear_details(title: String, status: String, step: String) -> void:
	_set_details(title, status, step)


func _on_active_selected(index: int) -> void:
	if index < 0 or index >= _active_ids.size():
		return
	_show_quest(_active_ids[index], true)


func _on_completed_selected(index: int) -> void:
	if index < 0 or index >= _completed_ids.size():
		return
	_show_quest(_completed_ids[index], false)


func _on_quest_changed(_quest_id: StringName) -> void:
	refresh()


func _on_quest_changed_step(_quest_id: StringName, _step_index: int) -> void:
	refresh()
