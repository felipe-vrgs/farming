@tool
class_name RewardPopup
extends PanelContainer

const _DEFAULT_COUNT_LABEL_SETTINGS: LabelSettings = preload(
	"res://game/ui/theme/label_settings_x_small.tres"
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
@onready var objective_label: Label = %ObjectiveLabel
@onready var rows_container: VBoxContainer = %Rows
@onready var hint_label: Label = %Hint

var _hide_tween: Tween = null


func _ready() -> void:
	# Must run while SceneTree is paused (GrantRewardState pauses the tree).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# In-editor we want preview visible; in-game we start hidden.
	visible = Engine.is_editor_hint() and preview_visible
	if Engine.is_editor_hint():
		call_deferred("_apply_preview")


func show_quest_update(
	questline_name: String,
	icon: Texture2D,
	progress: int,
	target: int,
	duration: float = 2.5,
	action: String = ""
) -> void:
	var entries: Array[Dictionary] = []
	if icon != null and int(target) > 0:
		entries.append({"icon": icon, "progress": int(progress), "target": int(target)})
	var subtitle := "New Objective:"
	var a := String(action).strip_edges()
	if not a.is_empty():
		subtitle = "New Objective: %s" % a
	show_popup(questline_name, subtitle, entries, duration, true, false)


func show_rewards(title: String, entries: Array[Dictionary]) -> void:
	# Used by GRANT_REWARD flow; no auto-hide, show input hint.
	show_popup(title, "Rewards:", entries, 0.0, false, true)


func show_popup(
	title: String,
	subtitle: String,
	entries: Array[Dictionary],
	duration: float,
	auto_hide: bool,
	show_hint: bool
) -> void:
	visible = true
	modulate.a = 1.0

	if questline_name_label != null:
		questline_name_label.text = title if not title.is_empty() else "Quest"
	if objective_label != null:
		objective_label.text = subtitle if not subtitle.is_empty() else ""
	if hint_label != null:
		hint_label.visible = show_hint

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


func _set_entries(entries: Array[Dictionary]) -> void:
	if rows_container == null:
		return
	for c in rows_container.get_children():
		c.queue_free()

	if entries == null or entries.is_empty():
		return

	var row: HBoxContainer = null
	var in_row := 0
	var max_in_row := maxi(1, int(max_entries_per_row))

	for e in entries:
		if e == null:
			continue
		var icon: Texture2D = e.get("icon") as Texture2D
		if icon == null:
			continue

		if row == null or in_row >= max_in_row:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.process_mode = Node.PROCESS_MODE_ALWAYS
			rows_container.add_child(row)
			in_row = 0

		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.process_mode = Node.PROCESS_MODE_ALWAYS

		var tex := TextureRect.new()
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.custom_minimum_size = Vector2(6, 6)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture = icon
		cell.add_child(tex)

		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count_text := ""
		if e.has("count_text"):
			count_text = String(e.get("count_text"))
		elif e.has("progress") and e.has("target"):
			count_text = QuestUiHelper.format_progress(int(e.get("progress")), int(e.get("target")))
		elif e.has("count"):
			count_text = "x%d" % int(e.get("count"))
		lbl.text = count_text
		if count_label_settings != null:
			lbl.label_settings = count_label_settings
		cell.add_child(lbl)

		row.add_child(cell)
		in_row += 1


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
	var action := ""

	if preview_quest != null:
		title = preview_quest.title
		if title.is_empty():
			title = String(preview_quest.id)
		if title.is_empty():
			title = "Quest"
		var next_idx := int(preview_completed_step_index) + 1
		if next_idx >= 0 and next_idx < preview_quest.steps.size():
			var st: QuestStep = preview_quest.steps[next_idx]
			if st != null and st.objective is QuestObjectiveItemCount:
				var o := st.objective as QuestObjectiveItemCount
				var d := QuestUiHelper.build_item_count_display(o, 0)
				var found_icon := d.get("icon") as Texture2D
				if found_icon != null:
					icon = found_icon
					progress = int(d.get("progress", 0))
					target = int(d.get("target", target))
					action = String(d.get("action", "")).strip_edges()

	var entries: Array[Dictionary] = []
	if icon != null and target > 0:
		entries.append({"icon": icon, "progress": progress, "target": target})

	# For preview we keep it visible (no auto-hide) and hide input hint.
	var subtitle := "New Objective:"
	if not action.is_empty():
		subtitle = "New Objective: %s" % action
	show_popup(title, subtitle, entries, 0.0, false, false)
