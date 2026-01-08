@tool
class_name RewardPopup
extends Control

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

@onready var questline_name_label: Label = %QuestlineName
@onready var objective_label: Label = %ObjectiveLabel
@onready var entries_container: VBoxContainer = %Entries
@onready var hint_label: Label = %Hint

var _hide_tween: Tween = null
var _item_cache: Dictionary = {}  # StringName -> ItemData (or null)


func _ready() -> void:
	# Must run while SceneTree is paused (GrantRewardState pauses the tree).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# In-editor we want preview visible; in-game we start hidden.
	visible = Engine.is_editor_hint() and preview_visible
	if Engine.is_editor_hint():
		call_deferred("_apply_preview")


func show_quest_update(
	questline_name: String, icon: Texture2D, count: int, duration: float = 2.5
) -> void:
	var entries: Array[Dictionary] = []
	if icon != null and int(count) > 0:
		entries.append({"icon": icon, "count": int(count)})
	show_popup(questline_name, "New Objective:", entries, duration, true, false)


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
	if entries_container == null:
		return
	for c in entries_container.get_children():
		c.queue_free()

	if entries == null or entries.is_empty():
		return

	for e in entries:
		if e == null:
			continue
		var icon: Texture2D = e.get("icon") as Texture2D
		var count := int(e.get("count", 0))
		if icon == null or count <= 0:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.process_mode = Node.PROCESS_MODE_ALWAYS

		var tex := TextureRect.new()
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.custom_minimum_size = Vector2(14, 14)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture = icon
		row.add_child(tex)

		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.text = "x%d" % count
		lbl.add_theme_font_size_override("font_size", 6)
		row.add_child(lbl)

		entries_container.add_child(row)


func _apply_preview() -> void:
	if not Engine.is_editor_hint():
		return

	if not preview_visible:
		visible = false
		return

	var title := "Quest"
	var icon: Texture2D = preview_fallback_icon
	var count := int(preview_fallback_count)

	if preview_quest != null:
		title = preview_quest.title
		if title.is_empty():
			title = String(preview_quest.id)
		if title.is_empty():
			title = "Quest"
		var next := _get_next_objective_icon_and_count(preview_quest, preview_completed_step_index)
		var found_icon := next.get("icon") as Texture2D
		var found_count := int(next.get("count", 0))
		if found_icon != null and found_count > 0:
			icon = found_icon
			count = found_count

	var entries: Array[Dictionary] = []
	if icon != null and count > 0:
		entries.append({"icon": icon, "count": count})

	# For preview we keep it visible (no auto-hide) and hide input hint.
	show_popup(title, "New Objective:", entries, 0.0, false, false)


func _get_next_objective_icon_and_count(
	def: QuestResource, completed_step_index: int
) -> Dictionary:
	# Returns {"icon": Texture2D, "count": int} for the next step
	# if it's an item-count objective.
	if def == null:
		return {}
	var next_idx := int(completed_step_index) + 1
	if def.steps == null or next_idx < 0 or next_idx >= def.steps.size():
		return {}
	var st: QuestStep = def.steps[next_idx]
	if st == null or st.objective == null:
		return {}
	if st.objective is QuestObjectiveItemCount:
		var o := st.objective as QuestObjectiveItemCount
		var item := _resolve_item_data(o.item_id)
		if item != null and item.icon != null:
			return {"icon": item.icon, "count": int(o.target_count)}
	return {}


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
