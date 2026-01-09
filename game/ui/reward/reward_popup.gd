@tool
class_name RewardPopup
extends PanelContainer

const _PORTRAIT_SCENE: PackedScene = preload(
	"res://game/ui/player_menu/relationships/npc_portrait.tscn"
)
const _NPC_ICON_SIZE := Vector2(24, 24)

const _DEFAULT_COUNT_LABEL_SETTINGS: LabelSettings = preload(
	"res://game/ui/theme/label_settings_default.tres"
)

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
@export var max_entries_per_row: int = 4:
	set(v):
		max_entries_per_row = clampi(int(v), 1, 12)
		_apply_preview()

@export var count_label_settings: LabelSettings = _DEFAULT_COUNT_LABEL_SETTINGS

@onready var questline_name_label: Label = %QuestlineName
@onready var next_objective_label: Label = %NextObjectiveLabel
@onready var rows_scroll: ScrollContainer = %Rows
@onready var entries_container: HBoxContainer = %Entries

var _hide_tween: Tween = null


func _ready() -> void:
	# Must work while SceneTree is paused (menus/dialogue/etc).
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var entries: Array[QuestUiHelper.ItemCountDisplay] = []
	var icd = QuestUiHelper.ItemCountDisplay.new()
	icd.icon = icon
	icd.item_name = String(objective_text).strip_edges()
	icd.npc_id = npc_id
	entries.append(icd)
	show_popup(questline_name, "QUEST UPDATE", entries, duration, true)


func show_quest_completed(
	questline_name: String,
	reward_icon: Array[Texture2D] = [],
	reward_count: Array[int] = [],
	duration: float = 2.5
) -> void:
	# Brief celebratory toast-like popup, but using the quest popup visuals.
	var entries: Array[QuestUiHelper.ItemCountDisplay] = []
	var n := mini(reward_icon.size(), reward_count.size())
	if n > 0:
		for i in range(n):
			var icd = QuestUiHelper.ItemCountDisplay.new()
			icd.icon = reward_icon[i]
			icd.item_name = ("x%d" % reward_count[i]) if reward_count[i] > 1 else ""
			entries.append(icd)
	show_popup(questline_name, "QUEST COMPLETE", entries, duration, true)


func show_quest_started(
	questline_name: String,
	objective_text: String,
	icon: Texture2D = null,
	duration: float = 3.5,
	npc_id: StringName = &""
) -> void:
	# New quest notification, showing the current objective like the quest menu.
	var entries: Array[QuestUiHelper.ItemCountDisplay] = []
	var icd = QuestUiHelper.ItemCountDisplay.new()
	icd.icon = icon
	icd.item_name = String(objective_text).strip_edges()
	icd.npc_id = npc_id
	entries.append(icd)
	show_popup(questline_name, "NEW QUEST", entries, duration, true)


func show_popup(
	questline_name: String,
	heading_left: String,
	entries: Array[QuestUiHelper.ItemCountDisplay],
	duration: float,
	auto_hide: bool
) -> void:
	visible = true
	modulate.a = 1.0

	if questline_name_label != null:
		questline_name_label.text = questline_name if not questline_name.is_empty() else "Quest"
	if next_objective_label != null:
		next_objective_label.text = heading_left if not heading_left.is_empty() else ""

	_set_entries(entries)

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


func _set_entries(entries: Array[QuestUiHelper.ItemCountDisplay]) -> void:
	if entries_container == null:
		return
	for c in entries_container.get_children():
		c.queue_free()
	if rows_scroll != null:
		# Ensure the user always sees the start of the line.
		rows_scroll.scroll_horizontal = 0

	if entries == null or entries.is_empty():
		return

	# Render in a single horizontal line: each entry is icon + text.
	# (ScrollContainer ensures we don't clip when there are many entries.)
	for e in entries:
		if e == null:
			continue
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 6)
		entry.alignment = BoxContainer.ALIGNMENT_CENTER
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.process_mode = Node.PROCESS_MODE_ALWAYS
		entries_container.add_child(entry)

		if not String(e.npc_id).is_empty() and _PORTRAIT_SCENE != null:
			# Use an animated NPC portrait when we know the npc_id.
			var portrait := _PORTRAIT_SCENE.instantiate() as Control
			if portrait != null:
				if "portrait_size" in portrait:
					portrait.set("portrait_size", _NPC_ICON_SIZE)
				else:
					portrait.custom_minimum_size = _NPC_ICON_SIZE
				if portrait.has_method("setup_from_npc_id"):
					portrait.call("setup_from_npc_id", e.npc_id)
				entry.add_child(portrait)
		elif e.icon != null:
			var tex := TextureRect.new()
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex.custom_minimum_size = Vector2(16, 16)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.texture = e.icon
			entry.add_child(tex)

		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var txt := String(e.item_name).strip_edges()
		if txt.is_empty():
			txt = String(e.count_text).strip_edges()
		lbl.text = txt
		if count_label_settings != null:
			# This label settings is now used as the objective line text style.
			lbl.label_settings = count_label_settings
		entry.add_child(lbl)


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
		title = preview_quest.title
		if title.is_empty():
			title = String(preview_quest.id)
		if title.is_empty():
			title = "Quest"
		var next_idx := int(preview_completed_step_index) + 1
		if next_idx >= 0 and next_idx < preview_quest.steps.size():
			var st: QuestStep = preview_quest.steps[next_idx]
			if st != null and st.objective != null:
				var d: QuestUiHelper.ItemCountDisplay = null
				if st.objective is QuestObjectiveItemCount:
					d = QuestUiHelper.build_item_count_display(
						st.objective as QuestObjectiveItemCount, 0
					)
				elif st.objective is QuestObjectiveTalk:
					d = QuestUiHelper.build_talk_display(st.objective as QuestObjectiveTalk, 0)
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
