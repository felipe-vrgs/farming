@tool
class_name RewardPopup
extends PanelContainer

const _DEFAULT_COUNT_LABEL_SETTINGS: LabelSettings = preload(
	"res://game/ui/theme/label_settings_default.tres"
)
const _ACTION_OPEN_QUESTS: StringName = &"open_player_menu_quests"
const _DEFAULT_QUEST_EVENT_DURATION_SEC := 4.0
const _ENTRY_GROUP: StringName = &"_reward_popup_entry"

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
@export var preview_show_hint: bool = true:
	set(v):
		preview_show_hint = bool(v)
		_apply_preview()
@export var preview_fit_to_content_in_editor: bool = true:
	set(v):
		preview_fit_to_content_in_editor = bool(v)
		_apply_preview()
@export var preview_sample_entry_count: int = 3:
	set(v):
		preview_sample_entry_count = clampi(int(v), 0, 12)
		_apply_preview()
@export var preview_sample_text: String = "Bring 10 berries to the village elder (0/10)":
	set(v):
		preview_sample_text = String(v)
		_apply_preview()

@export_group("Layout")
@export var max_entries_per_row: int = 3:
	set(v):
		max_entries_per_row = clampi(int(v), 1, 12)
		_apply_preview()

@export var max_visible_entries: int = 4:
	set(v):
		max_visible_entries = clampi(int(v), 1, 99)
		_apply_preview()

@export var show_overflow_summary: bool = true:
	set(v):
		show_overflow_summary = bool(v)
		_apply_preview()

@export var max_height_px: int = 220
@export var max_width_px: int = 420
@export var min_width_px: int = 140
@export var min_height_px: int = 56

@export var count_label_settings: LabelSettings = _DEFAULT_COUNT_LABEL_SETTINGS

@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var _root: VBoxContainer = get_node_or_null("Root") as VBoxContainer
@onready var _hint_row: Control = get_node_or_null("Root/HintRow") as Control
@onready var questline_name_label: Label = %QuestlineName
@onready var next_objective_label: Label = %NextObjectiveLabel
@onready var entries_container: Control = %Entries
@onready var hint_label: Label = %HintLabel

var _base_size: Vector2 = Vector2.ZERO
var _can_open_quests_from_popup: bool = false

var _hide_tween: Tween = null
var _pending_hide: bool = false

# Live quest tracking (runtime only): lets the popup refresh while open.
var _tracked_quest_id: StringName = &""
var _tracked_kind: String = ""
var _tracked_step_index: int = 0
var _tracked_title: String = ""
var _tracked_duration: float = 0.0


func _ready() -> void:
	# Must work while SceneTree is paused (menus/dialogue/etc).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_base_size = size
	_ensure_animations()
	# Treat Entries as a scene-marker, not a layout container.
	if entries_container != null:
		entries_container.visible = false

	# In-editor we want preview visible; in-game we start hidden.
	visible = Engine.is_editor_hint() and preview_visible
	if Engine.is_editor_hint():
		call_deferred("_apply_preview")
	else:
		_bind_live_quest_updates()


func _ensure_animations() -> void:
	if _anim == null:
		return
	_anim.process_mode = Node.PROCESS_MODE_ALWAYS
	if not _anim.animation_finished.is_connected(_on_animation_finished):
		_anim.animation_finished.connect(_on_animation_finished)

	var lib := _get_or_create_animation_library()
	if lib == null:
		return

	# Upgrade safety: older runtime-created animations used "..:modulate"/"..:scale"
	# (which can accidentally target the wrong node, depending on AnimationPlayer root).
	if _anim.has_animation("intro"):
		var a := _anim.get_animation("intro")
		if a != null and a.get_track_count() > 0 and a.track_get_path(0) == NodePath("..:modulate"):
			lib.remove_animation(&"intro")
	if _anim.has_animation("outro"):
		var a2 := _anim.get_animation("outro")
		if (
			a2 != null
			and a2.get_track_count() > 0
			and a2.track_get_path(0) == NodePath("..:modulate")
		):
			lib.remove_animation(&"outro")

	if not _anim.has_animation("intro"):
		var intro := Animation.new()
		intro.length = 0.22
		intro.loop_mode = Animation.LOOP_NONE

		var t_mod := intro.add_track(Animation.TYPE_VALUE)
		intro.track_set_path(t_mod, NodePath(".:modulate"))
		intro.track_insert_key(t_mod, 0.0, Color(1, 1, 1, 0))
		intro.track_insert_key(t_mod, 0.22, Color(1, 1, 1, 1))

		var t_scale := intro.add_track(Animation.TYPE_VALUE)
		intro.track_set_path(t_scale, NodePath(".:scale"))
		intro.track_insert_key(t_scale, 0.0, Vector2(0.85, 0.85))
		intro.track_insert_key(t_scale, 0.12, Vector2(1.10, 1.10))
		intro.track_insert_key(t_scale, 0.22, Vector2(1, 1))

		lib.add_animation(&"intro", intro)

	if not _anim.has_animation("outro"):
		var outro := Animation.new()
		outro.length = 0.18
		outro.loop_mode = Animation.LOOP_NONE

		var t_mod2 := outro.add_track(Animation.TYPE_VALUE)
		outro.track_set_path(t_mod2, NodePath(".:modulate"))
		outro.track_insert_key(t_mod2, 0.0, Color(1, 1, 1, 1))
		outro.track_insert_key(t_mod2, 0.18, Color(1, 1, 1, 0))

		var t_scale2 := outro.add_track(Animation.TYPE_VALUE)
		outro.track_set_path(t_scale2, NodePath(".:scale"))
		outro.track_insert_key(t_scale2, 0.0, Vector2(1, 1))
		outro.track_insert_key(t_scale2, 0.18, Vector2(0.98, 0.98))

		lib.add_animation(&"outro", outro)


func _get_or_create_animation_library() -> AnimationLibrary:
	# Godot 4 stores animations inside libraries (Godot 3 had add_animation()).
	if _anim == null:
		return null

	var lib_name: StringName = &""
	if _anim.has_animation_library(lib_name):
		return _anim.get_animation_library(lib_name)

	var lib := AnimationLibrary.new()
	_anim.add_animation_library(lib_name, lib)
	return lib


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"outro" and _pending_hide:
		_pending_hide = false
		# Safety: reset visual state so future screens aren't affected.
		modulate = Color(1, 1, 1, 1)
		scale = Vector2.ONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false


func _exit_tree() -> void:
	_unbind_live_quest_updates()


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
	_clear_tracked_quest()
	_show_popup_impl(questline_name, heading_left, entries, duration, auto_hide)


func _show_popup_impl(
	questline_name: String, heading_left: String, entries: Array, duration: float, auto_hide: bool
) -> void:
	visible = true
	_pending_hide = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	if questline_name_label != null:
		questline_name_label.text = questline_name if not questline_name.is_empty() else "Quest"
	if next_objective_label != null:
		next_objective_label.text = heading_left if not heading_left.is_empty() else ""

	_set_entries(entries)
	call_deferred("_fit_to_content")
	call_deferred("_play_intro")

	if _hide_tween != null and is_instance_valid(_hide_tween):
		_hide_tween.kill()
		_hide_tween = null

	if auto_hide:
		_hide_tween = create_tween()
		_hide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_hide_tween.tween_interval(maxf(0.25, float(duration)))
		_hide_tween.tween_callback(Callable(self, "_play_outro"))


func hide_popup() -> void:
	if _hide_tween != null and is_instance_valid(_hide_tween):
		_hide_tween.kill()
		_hide_tween = null
	_clear_tracked_quest()
	_pending_hide = false
	if _anim != null:
		_anim.stop()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _play_intro() -> void:
	if not is_visible_in_tree():
		return
	if _anim == null or not _anim.has_animation("intro"):
		# Fallback: just show.
		modulate.a = 1.0
		scale = Vector2.ONE
		return

	# Ensure scaling pops from the center.
	await get_tree().process_frame
	pivot_offset = size * 0.5
	_anim.stop()
	_anim.play("intro")


func _play_outro() -> void:
	if not is_visible_in_tree():
		return
	if _anim == null or not _anim.has_animation("outro"):
		visible = false
		return
	_pending_hide = true
	_anim.stop()
	_anim.play("outro")


func show_quest_event(ev: QuestPopupQueue.Event) -> void:
	# Render from current quest state (not from possibly stale precomputed entries).
	if ev == null:
		return
	var quest_id: StringName = ev.quest_id
	if String(quest_id).is_empty():
		# Fallback to raw popup if no quest_id.
		show_popup(ev.title, ev.heading, ev.entries, float(ev.duration), true)
		return

	_tracked_quest_id = quest_id
	_tracked_kind = String(ev.kind)
	_tracked_step_index = int(ev.step_index)
	_tracked_title = String(ev.title).strip_edges()
	_tracked_duration = float(ev.duration)

	var title := _resolve_quest_title(quest_id, _tracked_title)
	var heading := _heading_for_kind(_tracked_kind, String(ev.heading))
	var entries := _build_entries_for_tracked()
	var duration := float(_tracked_duration)
	if duration <= 0.0:
		duration = _DEFAULT_QUEST_EVENT_DURATION_SEC
	_show_popup_impl(title, heading, entries, duration, true)


func handle_quest_signal(kind: String, quest_id: StringName, step_index: int = 0) -> bool:
	# Called by UIManager to refresh an already-visible popup in-place.
	if not is_visible_in_tree():
		return false
	if String(_tracked_quest_id).is_empty() or _tracked_quest_id != quest_id:
		return false

	var k := String(kind)
	if k.is_empty():
		return false

	# If the quest completed, stop tracking objective updates afterwards.
	_tracked_kind = k
	_tracked_step_index = int(step_index)

	# Reset timer for major transitions so the player has time to read.
	var reset_timer := k == "step" or k == "completed"
	_refresh_tracked(reset_timer)
	return true


func _clear_tracked_quest() -> void:
	_tracked_quest_id = &""
	_tracked_kind = ""
	_tracked_step_index = 0
	_tracked_title = ""
	_tracked_duration = 0.0


func _refresh_tracked(reset_timer: bool) -> void:
	if String(_tracked_quest_id).is_empty():
		return
	if not is_visible_in_tree():
		return

	var title := _resolve_quest_title(_tracked_quest_id, _tracked_title)
	var heading := _heading_for_kind(_tracked_kind, "")
	var entries := _build_entries_for_tracked()

	if reset_timer:
		var duration := float(_tracked_duration)
		if duration <= 0.0:
			duration = _DEFAULT_QUEST_EVENT_DURATION_SEC
		# Restart auto-hide timing for major transitions (but keep tracking state).
		_show_popup_impl(title, heading, entries, duration, true)
		return

	# In-place update: keep current hide tween/timing.
	_update_content_in_place(title, heading, entries)


func _update_content_in_place(title: String, heading: String, entries: Array) -> void:
	if questline_name_label != null:
		questline_name_label.text = title if not title.is_empty() else "Quest"
	if next_objective_label != null:
		next_objective_label.text = heading if not heading.is_empty() else ""
	_set_entries(entries)
	call_deferred("_fit_to_content")


func _heading_for_kind(kind: String, fallback: String) -> String:
	var k := String(kind).strip_edges()
	if k == "started":
		return "NEW QUEST"
	if k == "step":
		return "QUEST UPDATE"
	if k == "completed":
		return "QUEST COMPLETE"
	return String(fallback).strip_edges()


func _resolve_quest_title(quest_id: StringName, fallback: String = "") -> String:
	var t := String(fallback).strip_edges()
	if not t.is_empty():
		return t
	var out := String(quest_id)
	if out.is_empty():
		return "Quest"
	if QuestManager != null:
		var def: QuestResource = QuestManager.get_quest_definition(quest_id) as QuestResource
		if def != null and not String(def.title).strip_edges().is_empty():
			return String(def.title).strip_edges()
	return out


func _build_entries_for_tracked() -> Array:
	var out: Array = []
	if String(_tracked_quest_id).is_empty():
		return out

	var kind := String(_tracked_kind)
	if kind == "completed":
		if QuestManager != null:
			var def: QuestResource = (
				QuestManager.get_quest_definition(_tracked_quest_id) as QuestResource
			)
			if (
				def != null
				and def.completion_rewards != null
				and not def.completion_rewards.is_empty()
			):
				out = QuestUiHelper.build_reward_displays(def.completion_rewards)
		return out

	# For started/step popups, always show the *current* active step objective (live progress).
	if QuestManager != null and bool(QuestManager.is_quest_active(_tracked_quest_id)):
		var step_idx := int(QuestManager.get_active_quest_step(_tracked_quest_id))
		if step_idx >= 0:
			var obj := QuestUiHelper.build_objective_display_for_quest_step(
				_tracked_quest_id, step_idx, QuestManager
			)
			if obj != null:
				out = [obj]

	return out


func _bind_live_quest_updates() -> void:
	# Keep headless tests deterministic and avoid UI node churn/leaks.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		return
	if EventBus == null:
		return
	# NOTE: QuestPanel listens to these same signals for live refresh.
	if "quest_event" in EventBus and not EventBus.quest_event.is_connected(_on_quest_event):
		EventBus.quest_event.connect(_on_quest_event)
	if (
		"quest_step_completed" in EventBus
		and not EventBus.quest_step_completed.is_connected(_on_quest_step_completed)
	):
		EventBus.quest_step_completed.connect(_on_quest_step_completed)
	if (
		"quest_completed" in EventBus
		and not EventBus.quest_completed.is_connected(_on_quest_completed)
	):
		EventBus.quest_completed.connect(_on_quest_completed)


func _unbind_live_quest_updates() -> void:
	if EventBus == null:
		return
	if "quest_event" in EventBus and EventBus.quest_event.is_connected(_on_quest_event):
		EventBus.quest_event.disconnect(_on_quest_event)
	if (
		"quest_step_completed" in EventBus
		and EventBus.quest_step_completed.is_connected(_on_quest_step_completed)
	):
		EventBus.quest_step_completed.disconnect(_on_quest_step_completed)
	if "quest_completed" in EventBus and EventBus.quest_completed.is_connected(_on_quest_completed):
		EventBus.quest_completed.disconnect(_on_quest_completed)


func _on_quest_event(_event_id: StringName, _payload: Dictionary) -> void:
	# Objective progress can change without completing the step.
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if String(_tracked_quest_id).is_empty():
		return
	if String(_tracked_kind) == "completed":
		return
	_refresh_tracked(false)


func _on_quest_step_completed(quest_id: StringName, step_index: int) -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if String(_tracked_quest_id).is_empty() or _tracked_quest_id != quest_id:
		return
	# Transition into "quest update" mode and show the new active step objective.
	_tracked_kind = "step"
	_tracked_step_index = int(step_index)
	_refresh_tracked(true)


func _on_quest_completed(quest_id: StringName) -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if String(_tracked_quest_id).is_empty() or _tracked_quest_id != quest_id:
		return
	_tracked_kind = "completed"
	_refresh_tracked(true)


func _set_entries(entries: Array) -> void:
	if _root == null:
		return
	_clear_entry_nodes()
	if entries_container != null:
		entries_container.visible = false
	# IMPORTANT: Use immediate removal/free so frequent updates within the same frame
	# don't accumulate stale rows in layout calculations (which can cause the popup
	# to only ever grow, never shrink).
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

	# Render one entry per row (vertical list).
	var insert_at := _insert_index_for_entries()
	var wrap_min := _wrap_min_text_width_for_entries(1)
	# If all entries are short, don't impose a minimum width (keeps popup compact).
	# If any entry is long, set a minimum width so wrapping looks intentional.
	if _max_entry_text_len(visible_entries) < 18:
		wrap_min = 0

	for e in visible_entries:
		if e == null:
			continue

		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.process_mode = Node.PROCESS_MODE_ALWAYS
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("separation", 10)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_to_group(_ENTRY_GROUP)
		_root.add_child(line)
		_root.move_child(line, insert_at)
		insert_at += 1

		var row := QuestDisplayRow.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.process_mode = Node.PROCESS_MODE_ALWAYS
		# Don't allow the row to become full-width; the wrapper line centers it.
		row.size_flags_horizontal = 0
		row.left_icon_size = Vector2(16, 16)
		row.portrait_size = Vector2(24, 24)
		row.label_settings = count_label_settings
		row.row_alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_child(row)

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
		summary_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_line.add_theme_constant_override("separation", 10)
		summary_line.alignment = BoxContainer.ALIGNMENT_CENTER
		summary_line.add_to_group(_ENTRY_GROUP)
		_root.add_child(summary_line)
		_root.move_child(summary_line, insert_at)
		insert_at += 1

		var summary := QuestDisplayRow.new()
		summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
		summary.process_mode = Node.PROCESS_MODE_ALWAYS
		summary.size_flags_horizontal = 0
		summary.left_icon_size = Vector2(16, 16)
		summary.portrait_size = Vector2(24, 24)
		summary.label_settings = count_label_settings
		summary.row_alignment = BoxContainer.ALIGNMENT_CENTER
		summary.wrap_text = true
		summary.wrap_min_text_width_px = wrap_min
		summary_line.add_child(summary)

		summary.setup_text_icon("+%d more" % overflow, null)
		_can_open_quests_from_popup = true

	# Always show the hint for quest-related popups (runtime only).
	# (In-editor preview stays clean unless you explicitly want it.)
	if not Engine.is_editor_hint():
		_can_open_quests_from_popup = true
		_set_hint(_format_open_quests_hint())
	elif preview_show_hint:
		_set_hint(_format_open_quests_hint())


func _set_hint(text: String) -> void:
	if hint_label == null:
		return
	var t := String(text).strip_edges()
	hint_label.text = t
	hint_label.visible = not t.is_empty()


func _fit_to_content() -> void:
	# Fit to content (up to caps).
	var desired := get_combined_minimum_size()
	var w := desired.x
	var h := desired.y

	# In-game we want the popup to shrink to its content.
	# In-editor we keep the original width as a minimum to avoid jitter while previewing.
	var min_w := float(maxi(0, int(min_width_px)))
	if Engine.is_editor_hint():
		if not preview_fit_to_content_in_editor and _base_size.x > 0.0:
			min_w = maxf(min_w, _base_size.x)
	if w < min_w:
		w = min_w
	if int(max_width_px) > 0:
		w = min(w, float(max_width_px))

	# In-game we want the popup to shrink to its content (no empty gap).
	# In-editor we keep the original height as a minimum to avoid jitter while previewing.
	var min_h := float(maxi(0, int(min_height_px)))
	if Engine.is_editor_hint():
		if not preview_fit_to_content_in_editor:
			min_h = _base_size.y if _base_size.y > 0.0 else 0.0
			min_h = maxf(min_h, float(maxi(0, int(min_height_px))))
	if h < min_h:
		h = min_h
	if int(max_height_px) > 0:
		h = min(h, float(max_height_px))
	size = Vector2(w, h)


func _wrap_min_text_width_for_entries(per_line: int) -> int:
	# Derive a sane minimum label width based on the popup's *current* width,
	# falling back to max_width if needed.
	var max_w := int(size.x)
	if max_w <= 0:
		max_w = int(max_width_px)
	if max_w <= 0:
		max_w = 320
	if int(max_width_px) > 0:
		max_w = mini(max_w, int(max_width_px))
	var sep := 10
	var padding := 16
	var available := max_w - padding - (maxi(1, int(per_line)) - 1) * sep
	var per_entry := int(floor(float(available) / float(maxi(1, int(per_line)))))
	# Subtract icon + internal spacing budget.
	var label_w := per_entry - 40
	# Cap by available space so this doesn't become a "fixed minimum width".
	var max_label := maxi(0, max_w - 80)
	return clampi(label_w, 0, max_label)


func _max_entry_text_len(entries: Array) -> int:
	var out := 0
	if entries == null:
		return out
	for e in entries:
		if e == null:
			continue
		var t := ""
		if e is QuestUiHelper.ObjectiveDisplay:
			t = String((e as QuestUiHelper.ObjectiveDisplay).text)
		elif e is QuestUiHelper.RewardDisplay:
			t = String((e as QuestUiHelper.RewardDisplay).text)
		elif e is QuestUiHelper.ItemCountDisplay:
			var legacy := e as QuestUiHelper.ItemCountDisplay
			t = String(legacy.item_name).strip_edges()
			if t.is_empty():
				t = String(legacy.count_text)
		else:
			t = String(e)
		out = maxi(out, String(t).strip_edges().length())
	return out


func _insert_index_for_entries() -> int:
	# Prefer inserting at the (hidden) Entries marker position so scenes can
	# control where entries appear.
	if _root == null:
		return 0
	if entries_container != null and entries_container.get_parent() == _root:
		return int(entries_container.get_index())
	if _hint_row != null and _hint_row.get_parent() == _root:
		return int(_hint_row.get_index())
	return _root.get_child_count()


func _clear_entry_nodes() -> void:
	if _root == null:
		return
	for c in _root.get_children():
		if c == null:
			continue
		if c.is_in_group(_ENTRY_GROUP):
			_root.remove_child(c)
			c.free()


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

	var entries: Array = []
	if icon != null and target > 0:
		var icd = QuestUiHelper.ItemCountDisplay.new()
		icd.icon = icon
		icd.progress = progress
		icd.target = target
		icd.count_text = QuestUiHelper.format_progress(progress, target)
		entries.append(icd)

	# If we couldn't build a meaningful objective entry from the quest, fall back
	# to sample entries so the editor preview always shows a "real" rendered layout.
	if entries.is_empty() and int(preview_sample_entry_count) > 0:
		var n := int(preview_sample_entry_count)
		for i in range(n):
			var o := QuestUiHelper.ObjectiveDisplay.new()
			o.icon = preview_fallback_icon
			o.text = String(preview_sample_text).strip_edges()
			entries.append(o)

	# For preview we keep it visible (no auto-hide) and hide input hint.
	show_popup(title, "NEXT OBJECTIVE", entries, 0.0, false)
