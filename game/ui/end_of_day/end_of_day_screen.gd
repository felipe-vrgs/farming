class_name EndOfDayScreen
extends CanvasLayer

signal closed

@export_group("Audio")
@export var summary_music_stream: AudioStream = preload("res://assets/music/farm_day_loop.ogg")
@export var summary_music_volume_db: float = -15.0
@export var summary_music_fade_in_s: float = 0.35
@export var summary_music_fade_out_s: float = 0.25

@export_group("Close Animation")
@export var close_fade_out_s: float = 0.18
@export var close_scale_to: Vector2 = Vector2(0.98, 0.98)

const _CONFETTI_CONFIG: ParticleConfig = preload(
	"res://game/entities/particles/resources/ui_reward_confetti.tres"
)
const _SPARKLE_CONFIG: ParticleConfig = preload(
	"res://game/entities/particles/resources/ui_reward_sparkle.tres"
)
const _MONEY_ICON: Texture2D = preload("res://assets/icons/money.png")

@onready var _root: Control = get_node_or_null("Root") as Control
@onready var _panel: Control = get_node_or_null("Root/Center/Panel") as Control
@onready var _title: Label = %Title
@onready var _reason: Label = %Reason
@onready var _quests_panel: QuestRowsPanel = %QuestsPanel
@onready var _crops_panel: QuestRowsPanel = %CropsPanel
@onready var _items_panel: QuestRowsPanel = %ItemsPanel
@onready var _shop_panel: QuestRowsPanel = %ShopPanel
@onready var _money_panel: QuestRowsPanel = %MoneyPanel
@onready var _continue_button: Button = %ContinueButton
@onready var _confetti_vfx: VFX = get_node_or_null("Root/ConfettiVFX") as VFX
@onready var _sparkle_vfx: VFX = get_node_or_null("Root/SparkleVFX") as VFX

var _model: Dictionary = {}
var _closing: bool = false
var _close_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(Groups.MODAL)

	# Play dedicated summary music (configurable) and fade in.
	if (
		is_instance_valid(SFXManager)
		and summary_music_stream != null
		and SFXManager.has_method("play_music")
	):
		SFXManager.play_music(
			summary_music_stream, maxf(0.0, summary_music_fade_in_s), summary_music_volume_db
		)

	# Setup + play a small celebratory VFX.
	if _confetti_vfx != null:
		_confetti_vfx.setup(_CONFETTI_CONFIG)
	if _sparkle_vfx != null:
		_sparkle_vfx.setup(_SPARKLE_CONFIG)
	call_deferred("_play_open_effects")

	if _continue_button != null:
		_continue_button.pressed.connect(_on_continue_pressed)
		_continue_button.grab_focus()

	if _root != null:
		_root.modulate.a = 1.0
	if _panel != null:
		_panel.scale = Vector2.ONE
	_apply_model()


func setup(model: Dictionary) -> void:
	_model = {} if model == null else model
	_apply_model()


func _on_continue_pressed() -> void:
	if _closing:
		return
	_closing = true

	if _continue_button != null:
		_continue_button.disabled = true

	# Fade out our music, then restore normal routing.
	if is_instance_valid(SFXManager) and SFXManager.has_method("fade_out_music"):
		SFXManager.fade_out_music(maxf(0.0, summary_music_fade_out_s))

	# Fade out the UI.
	if _close_tween != null and is_instance_valid(_close_tween):
		_close_tween.kill()
	_close_tween = create_tween()
	_close_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_close_tween.set_parallel(true)

	if _root != null:
		(
			_close_tween
			. tween_property(_root, "modulate:a", 0.0, maxf(0.0, close_fade_out_s))
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)

	if _panel != null:
		(
			_close_tween
			. tween_property(_panel, "scale", close_scale_to, maxf(0.0, close_fade_out_s))
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)

	_close_tween.set_parallel(false)
	_close_tween.tween_interval(maxf(0.0, summary_music_fade_out_s))
	_close_tween.tween_callback(
		func() -> void:
			if not is_instance_valid(SFXManager):
				return
			# After summary music fade-out completes, swap back to the level music stream
			# immediately (no tween), but keep it silent until SleepService fades back in.
			if SFXManager.has_method("prime_level_music_silent"):
				SFXManager.prime_level_music_silent()
			elif SFXManager.has_method("restore_level_audio"):
				SFXManager.restore_level_audio()
			elif SFXManager.has_method("refresh_audio_for_context"):
				SFXManager.refresh_audio_for_context()
	)

	await _close_tween.finished
	closed.emit()


func _play_open_effects() -> void:
	# Keep headless tests deterministic and avoid UI node churn/leaks.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		return
	# Let layout settle so label sizes/positions are valid.
	await get_tree().process_frame
	if not is_inside_tree() or not visible:
		return

	var rect := get_viewport().get_visible_rect()
	var top_center := rect.position + Vector2(rect.size.x * 0.5, 0.0)

	if _confetti_vfx != null and is_instance_valid(_confetti_vfx):
		_confetti_vfx.play(top_center, 500)

	var sparkle_pos := rect.position + (rect.size * 0.5)
	if _title != null and is_instance_valid(_title):
		sparkle_pos = _title.global_position + (_title.size * 0.5)
	if _sparkle_vfx != null and is_instance_valid(_sparkle_vfx):
		_sparkle_vfx.play(sparkle_pos, 510)


func _apply_model() -> void:
	if not is_inside_tree():
		return

	var day_idx := int(_model.get("day_index", 1))
	var reason := String(_model.get("reason", "")).strip_edges()

	if _title != null:
		_title.text = "Day %d Summary" % day_idx
	if _reason != null:
		_reason.text = _format_reason(reason)
		_reason.visible = not _reason.text.is_empty()

	_apply_quests_section()
	_apply_crops_section()
	_apply_items_section()
	_apply_shop_section()
	_apply_money_section()


func _format_reason(reason: String) -> String:
	if reason.is_empty():
		return ""
	if reason == "forced":
		return "You stayed up too late."
	if reason == "exhaustion":
		return "You collapsed from exhaustion."
	if reason == "sleep":
		return "You went to sleep."
	return reason


func _apply_quests_section() -> void:
	if _quests_panel == null:
		return

	var rows: Array = []

	# Highlights first.
	var completed: Array = _model.get("quests_completed", []) as Array
	var steps: Array = _model.get("quest_steps_completed", []) as Array

	if not completed.is_empty() or not steps.is_empty():
		rows.append({"text": "Quest updates today", "header": true})

		for qid_v in completed:
			var qid := StringName(String(qid_v))
			rows.append({"text": "✓ %s" % _quest_title(qid), "icon": null})

		for d_v in steps:
			if not (d_v is Dictionary):
				continue
			var d := d_v as Dictionary
			var qid2 := StringName(String(d.get("quest_id", "")))
			var step_idx := int(d.get("step_index", -1))
			if String(qid2).is_empty() or step_idx < 0:
				continue
			(
				rows
				. append(
					{
						"text": "✓ %s (step %d complete)" % [_quest_title(qid2), step_idx + 1],
						"icon": null,
					}
				)
			)

		rows.append({"spacer": true})

	# Snapshot: active quest progress.
	rows.append({"text": "Active quests", "header": true})

	if QuestManager == null:
		rows.append({"text": "QuestManager unavailable.", "icon": null})
		_quests_panel.set_rows(rows)
		return

	var active_ids: Array[StringName] = QuestManager.list_active_quests()
	if active_ids.is_empty():
		rows.append({"text": "No active quests.", "icon": null})
		_quests_panel.set_rows(rows)
		return

	for qid3 in active_ids:
		var step_idx3 := int(QuestManager.get_active_quest_step(qid3))
		var o := QuestUiHelper.build_objective_display_for_quest_step(qid3, step_idx3, QuestManager)
		if o != null:
			o.text = "%s: %s" % [_quest_title(qid3), String(o.text)]
			rows.append(o)
		else:
			rows.append({"text": _quest_title(qid3), "icon": null})

	_quests_panel.set_rows(rows)


func _quest_title(quest_id: StringName) -> String:
	if String(quest_id).is_empty():
		return ""
	if QuestManager != null:
		var def: QuestResource = QuestManager.get_quest_definition(quest_id)
		if def != null and not def.title.is_empty():
			return def.title
	return String(quest_id)


func _apply_crops_section() -> void:
	if _crops_panel == null:
		return
	var rows: Array = []
	rows.append({"text": "Crops", "header": true})

	var seeds: Dictionary = _model.get("seeds_planted", {}) as Dictionary
	var watered := int(_model.get("cells_watered", 0))
	var harvests: Dictionary = _model.get("harvests_by_plant", {}) as Dictionary

	rows.append({"text": "Watered cells: %d" % watered, "icon": null})

	if not seeds.is_empty():
		rows.append({"spacer": true})
		rows.append({"text": "Seeds planted", "header": true})
		for plant_id_v in seeds.keys():
			var plant_id := StringName(String(plant_id_v))
			var cnt := int(seeds.get(plant_id_v, 0))
			rows.append({"text": "%s x%d" % [_plant_name(plant_id), cnt], "icon": null})

	if not harvests.is_empty():
		rows.append({"spacer": true})
		rows.append({"text": "Harvests", "header": true})
		for plant_id_v2 in harvests.keys():
			var plant_id2 := StringName(String(plant_id_v2))
			var cnt2 := int(harvests.get(plant_id_v2, 0))
			rows.append({"text": "%s x%d" % [_plant_name(plant_id2), cnt2], "icon": null})

	_crops_panel.set_rows(rows)


func _plant_name(plant_id: StringName) -> String:
	var p := String(plant_id)
	if p.is_empty():
		return ""
	if ResourceLoader.exists(p):
		var res := load(p)
		if res is PlantData:
			var pd := res as PlantData
			if pd != null and not pd.plant_name.is_empty():
				return pd.plant_name
	return p.get_file().get_basename()


func _apply_items_section() -> void:
	if _items_panel == null:
		return
	var rows: Array = []
	rows.append({"text": "Items gained", "header": true})

	var items: Dictionary = _model.get("items_gained", {}) as Dictionary
	if items.is_empty():
		rows.append({"text": "None.", "icon": null})
		_items_panel.set_rows(rows)
		return

	# Stable-ish ordering: by display name, fallback to id.
	var keys: Array = items.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))

	for k in keys:
		var item_id := StringName(String(k))
		var cnt := int(items.get(k, 0))
		if cnt == 0:
			continue
		var item := QuestUiHelper.resolve_item_data(item_id)
		var item_name := String(item_id)
		var icon: Texture2D = null
		if item != null:
			icon = item.icon
			if not item.display_name.is_empty():
				item_name = item.display_name
		rows.append({"text": "%s x%d" % [item_name, cnt], "icon": icon})

	_items_panel.set_rows(rows)


func _apply_shop_section() -> void:
	if _shop_panel == null:
		return
	var rows: Array = []
	rows.append({"text": "Shop", "header": true})

	var buys: Dictionary = _model.get("shop_buys", {}) as Dictionary
	var sells: Dictionary = _model.get("shop_sells", {}) as Dictionary

	if buys.is_empty() and sells.is_empty():
		rows.append({"text": "No shop transactions.", "icon": null})
		_shop_panel.set_rows(rows)
		return

	if not buys.is_empty():
		rows.append({"text": "Bought", "header": true})
		for k in buys.keys():
			var item_id := StringName(String(k))
			var cnt := int(buys.get(k, 0))
			var item := QuestUiHelper.resolve_item_data(item_id)
			var item_name := String(item_id)
			var icon: Texture2D = null
			if item != null:
				icon = item.icon
				if not item.display_name.is_empty():
					item_name = item.display_name
			rows.append({"text": "%s x%d" % [item_name, cnt], "icon": icon})

	if not sells.is_empty():
		if not buys.is_empty():
			rows.append({"spacer": true})
		rows.append({"text": "Sold", "header": true})
		for k2 in sells.keys():
			var item_id2 := StringName(String(k2))
			var cnt2 := int(sells.get(k2, 0))
			var item2 := QuestUiHelper.resolve_item_data(item_id2)
			var item_name2 := String(item_id2)
			var icon2: Texture2D = null
			if item2 != null:
				icon2 = item2.icon
				if not item2.display_name.is_empty():
					item_name2 = item2.display_name
			rows.append({"text": "%s x%d" % [item_name2, cnt2], "icon": icon2})

	_shop_panel.set_rows(rows)


func _apply_money_section() -> void:
	if _money_panel == null:
		return
	var rows: Array = []
	rows.append({"text": "Money", "header": true})

	var start := int(_model.get("money_start", 0))
	var end_amt := int(_model.get("money_end", start))
	var delta := int(_model.get("money_delta", end_amt - start))

	var delta_text := "+%d" % delta if delta >= 0 else "%d" % delta
	rows.append({"text": "Delta: %s" % delta_text, "icon": _MONEY_ICON})
	rows.append({"text": "Ending balance: %d" % end_amt, "icon": _MONEY_ICON})

	_money_panel.set_rows(rows)
