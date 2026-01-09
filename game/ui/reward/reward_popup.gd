@tool
class_name RewardPopup
extends PanelContainer

const _DEFAULT_COUNT_LABEL_SETTINGS: LabelSettings = preload(
	"res://game/ui/theme/label_settings_default.tres"
)
const _ACTION_OPEN_QUESTS: StringName = &"open_player_menu_quests"

@export_group("Preview (Editor)")
@export var preview_quest: QuestResource = null:
	set(v):
		preview_quest = v
		_apply_preview()
## Index of the step that was just completed (we preview the *next* step).
@export var preview_completed_step_index: int = 0:
	set(v):
		preview_completed_step_index = int(v)
		_apply_preview()
@export var preview_fallback_icon: Texture2D = null:
	set(v):
		preview_fallback_icon = v
		_apply_preview()
@export var preview_fallback_count: int = 1:
	set(v):
		preview_fallback_count = maxi(1, int(v))
		_apply_preview()
@export var preview_visible: bool = true:
	set(v):
		preview_visible = bool(v)
		_apply_preview()

@export_group("Layout")
@export var max_entries_per_row: int = 1:
	set(v):
		max_entries_per_row = clampi(int(v), 1, 12)
		_apply_preview()

@export var max_visible_entries: int = 6:
	set(v):
		max_visible_entries = clampi(int(v), 1, 99)
		_apply_preview()

@export var show_overflow_summary: bool = true:
	set(v):
		show_overflow_summary = bool(v)
		_apply_preview()

@export var max_height_px: int = 160

@export var count_label_settings: LabelSettings = _DEFAULT_COUNT_LABEL_SETTINGS

@onready var questline_name_label: Label = %QuestlineName
@onready var next_objective_label: Label = %NextObjectiveLabel
@onready var entries_container: VBoxContainer = %Entries
@onready var hint_label: Label = %HintLabel

var _base_size: Vector2 = Vector2.ZERO
var _can_open_quests_from_popup: bool = false

var _hide_tween: Tween = null


func _ready() -> void:
	# Must work while SceneTree is paused (menus/dialogue/etc).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_base_size = size
	# In-editor we want preview visible; in-game we start hidden.
	visible = Engine.is_editor_hint() and preview_visible
	if Engine.is_editor_hint():
		call_deferred("_apply_preview")


func show_quest_update(
	questline_name: String,
	objective_text: String,
	icon: Texture2D = null,
	duration: float = 2.5,
	npc_id: StringName = &""
) -> void:
	var o := QuestUiHelper.ObjectiveDisplay.new()
	o.icon = icon
	o.text = String(objective_text).strip_edges()
	o.npc_id = npc_id
	show_popup(questline_name, "QUEST UPDATE", [o], duration, true)


func show_quest_completed(
	questline_name: String,
	reward_icon: Array[Texture2D] = [],
	reward_count: Array[int] = [],
	duration: float = 2.5
) -> void:
	# Brief celebratory toast-like popup, but using the quest popup visuals.
	var entries: Array[QuestUiHelper.RewardDisplay] = []
	var n := mini(reward_icon.size(), reward_count.size())
	if n > 0:
		for i in range(n):
			var d := QuestUiHelper.RewardDisplay.new()
			d.icon = reward_icon[i]
			var cnt := int(reward_count[i])
			d.text = ("x%d" % cnt) if cnt > 1 else ""
			entries.append(d)
	show_popup(questline_name, "QUEST COMPLETE", entries, duration, true)


func show_quest_started(
	questline_name: String,
	objective_text: String,
	icon: Texture2D = null,
	duration: float = 3.5,
	npc_id: StringName = &""
) -> void:
	# New quest notification, showing the current objective like the quest menu.
	var o := QuestUiHelper.ObjectiveDisplay.new()
	o.icon = icon
	o.text = String(objective_text).strip_edges()
	o.npc_id = npc_id
	show_popup(questline_name, "NEW QUEST", [o], duration, true)


func show_popup(
	questline_name: String, heading_left: String, entries: Array, duration: float, auto_hide: bool
) -> void:
	visible = true
	modulate.a = 1.0

	if questline_name_label != null:
		questline_name_label.text = questline_name if not questline_name.is_empty() else "Quest"
	if next_objective_label != null:
		next_objective_label.text = heading_left if not heading_left.is_empty() else ""

	_set_entries(entries)
	call_deferred("_fit_to_content")

	if _hide_tween != null and is_instance_valid(_hide_tween):
		_hide_tween.kill()
		_hide_tween = null

	if auto_hide:
		_hide_tween = create_tween()
		_hide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_hide_tween.tween_interval(maxf(0.25, float(duration)))
		_hide_tween.tween_property(self, "modulate:a", 0.0, 0.25)
		_hide_tween.finished.connect(func(): visible = false)


func hide_popup() -> void:
	if _hide_tween != null and is_instance_valid(_hide_tween):
		_hide_tween.kill()
		_hide_tween = null
	visible = false


func _set_entries(entries: Array) -> void:
	if entries_container == null:
		return
	for c in entries_container.get_children():
		c.queue_free()
	_can_open_quests_from_popup = false
	_set_hint("")

	if entries == null or entries.is_empty():
		return

	var visible_entries := entries
	var overflow := 0
	if (
		show_overflow_summary
		and int(max_visible_entries) > 0
		and entries.size() > int(max_visible_entries)
	):
		overflow = entries.size() - int(max_visible_entries)
		visible_entries = entries.slice(0, int(max_visible_entries))

	# Render across multiple lines (rows), with up to N entries per line.
	var per_line := maxi(1, int(max_entries_per_row))
	var line: HBoxContainer = null
	var line_count := 0

	for e in visible_entries:
		if e == null:
			continue

		if line == null or line_count >= per_line:
			line = HBoxContainer.new()
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.process_mode = Node.PROCESS_MODE_ALWAYS
			line.add_theme_constant_override("separation", 10)
			line.alignment = BoxContainer.ALIGNMENT_CENTER
			entries_container.add_child(line)
			line_count = 0

		var row := QuestDisplayRow.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.process_mode = Node.PROCESS_MODE_ALWAYS
		row.left_icon_size = Vector2(16, 16)
		row.portrait_size = Vector2(24, 24)
		row.label_settings = count_label_settings
		line.add_child(row)
		line_count += 1

		if e is QuestUiHelper.ObjectiveDisplay:
			row.setup_objective(e as QuestUiHelper.ObjectiveDisplay)
		elif e is QuestUiHelper.RewardDisplay:
			row.setup_reward(e as QuestUiHelper.RewardDisplay)
		elif e is QuestUiHelper.ItemCountDisplay:
			var legacy := e as QuestUiHelper.ItemCountDisplay
			var o := QuestUiHelper.ObjectiveDisplay.new()
			o.icon = legacy.icon
			o.npc_id = legacy.npc_id
			var txt := String(legacy.item_name).strip_edges()
			if txt.is_empty():
				txt = String(legacy.count_text).strip_edges()
			o.text = txt
			row.setup_objective(o)
		else:
			row.setup_text_icon(String(e))

	if overflow > 0:
		var summary_line := HBoxContainer.new()
		summary_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		summary_line.process_mode = Node.PROCESS_MODE_ALWAYS
		summary_line.add_theme_constant_override("separation", 10)
		summary_line.alignment = BoxContainer.ALIGNMENT_CENTER
		entries_container.add_child(summary_line)

		var summary := QuestDisplayRow.new()
		summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
		summary.process_mode = Node.PROCESS_MODE_ALWAYS
		summary.left_icon_size = Vector2(16, 16)
		summary.portrait_size = Vector2(24, 24)
		summary.label_settings = count_label_settings
		summary_line.add_child(summary)

		summary.setup_text_icon("+%d more" % overflow, null)
		_can_open_quests_from_popup = true

	# Always show the hint for quest-related popups (runtime only).
	# (In-editor preview stays clean unless you explicitly want it.)
	if not Engine.is_editor_hint():
		_can_open_quests_from_popup = true
		_set_hint(_format_open_quests_hint())


func _set_hint(text: String) -> void:
	if hint_label == null:
		return
	var t := String(text).strip_edges()
	hint_label.text = t
	hint_label.visible = not t.is_empty()


func _fit_to_content() -> void:
	# Keep width stable, but allow height to expand to fit entries (up to a cap).
	var desired := get_combined_minimum_size()
	var w := _base_size.x if _base_size.x > 0.0 else size.x
	var h := desired.y
	# In-game we want the popup to shrink to its content (no empty gap).
	# In-editor we keep the original height as a minimum to avoid jitter while previewing.
	var min_h := 0.0
	if Engine.is_editor_hint():
		min_h = _base_size.y if _base_size.y > 0.0 else 0.0
	if h < min_h:
		h = min_h
	if int(max_height_px) > 0:
		h = min(h, float(max_height_px))
	size = Vector2(w, h)


func _unhandled_input(event: InputEvent) -> void:
	if event == null or not is_visible_in_tree():
		return
	if not _can_open_quests_from_popup:
		return
	if event.is_action_pressed(_ACTION_OPEN_QUESTS, false, true):
		if Runtime != null and Runtime.game_flow != null:
			Runtime.game_flow.request_player_menu(PlayerMenu.Tab.QUESTS)
			hide_popup()
			get_viewport().set_input_as_handled()
		return


func _format_open_quests_hint() -> String:
	var key := _get_first_key_label_for_action(_ACTION_OPEN_QUESTS)
	if key.is_empty():
		return "Quests"
	return "Quests (%s)" % key


func _get_first_key_label_for_action(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := OS.get_keycode_string(int((ev as InputEventKey).physical_keycode))
			return String(k).strip_edges()
	return ""


func _apply_preview() -> void:
	if not Engine.is_editor_hint():
		return

	if not preview_visible:
		visible = false
		return

	var title := "Quest"
	var icon: Texture2D = preview_fallback_icon
	var progress := 0
	var target := int(preview_fallback_count)

	if preview_quest != null:
		# Tool preview: Quest resources/steps/objectives can be placeholders in-editor
		# (script not loaded). Avoid dot-access in preview code.
		title = QuestUiHelper.safe_get_string(preview_quest, &"title", "")
		if title.is_empty():
			title = QuestUiHelper.safe_get_string(preview_quest, &"id", "")
		if title.is_empty():
			title = "Quest"
		var next_idx := int(preview_completed_step_index) + 1
		var steps := QuestUiHelper.safe_get_array(preview_quest, &"steps")
		if next_idx >= 0 and next_idx < steps.size():
			var st_any: Variant = steps[next_idx]
			var objective_res: Resource = null
			if st_any is Object:
				objective_res = QuestUiHelper.safe_get_resource(st_any as Object, &"objective")
			if objective_res != null:
				var d: QuestUiHelper.ItemCountDisplay = null
				if objective_res is QuestObjectiveItemCount:
					d = QuestUiHelper.build_item_count_display(
						objective_res as QuestObjectiveItemCount, 0
					)
				elif objective_res is QuestObjectiveTalk:
					d = QuestUiHelper.build_talk_display(objective_res as QuestObjectiveTalk, 0)
				if d != null:
					icon = d.icon
					progress = int(d.progress)
					target = int(d.target)

	var entries: Array[QuestUiHelper.ItemCountDisplay] = []
	if icon != null and target > 0:
		var icd = QuestUiHelper.ItemCountDisplay.new()
		icd.icon = icon
		icd.progress = progress
		icd.target = target
		icd.count_text = QuestUiHelper.format_progress(progress, target)
		entries.append(icd)

	# For preview we keep it visible (no auto-hide) and hide input hint.
	show_popup(title, "NEXT OBJECTIVE", entries, 0.0, false)
