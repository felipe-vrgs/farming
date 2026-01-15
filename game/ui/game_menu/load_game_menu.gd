class_name LoadGameMenu
extends Control

enum MenuMode { LOAD, SAVE }

const SAVE_SLOT_ROW_SCENE: PackedScene = preload("res://game/ui/game_menu/save_slot_row.tscn")
const SLOT_IDS: Array[String] = [
	"default",
	"slot_02",
	"slot_03",
	"slot_04",
	"slot_05",
	"slot_06",
	"slot_07",
	"slot_08",
	"slot_09",
	"slot_10",
]
const LEVEL_NAMES := {
	Enums.Levels.ISLAND: "Island",
	Enums.Levels.FRIEREN_HOUSE: "Frieren House",
	Enums.Levels.PLAYER_HOUSE: "Player House",
}

@onready var slot_list: VBoxContainer = $VBoxContainer/ScrollContainer/SlotList
@onready var autosave_container: VBoxContainer = $VBoxContainer/AutosaveContainer
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var new_slot_button: Button = $VBoxContainer/NewSlotButton
@onready var back_button: Button = $VBoxContainer/BackButton

var _mode: int = MenuMode.LOAD
var _return_screen: int = UIManager.ScreenName.MAIN_MENU
var _autosave_row: SaveSlotRow = null
var _available_slot_ids: Array[String] = []


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	visibility_changed.connect(_on_visibility_changed)
	if new_slot_button != null:
		new_slot_button.pressed.connect(_on_new_slot_pressed)
	_ensure_autosave_row()
	_refresh_header()
	_refresh_slots()


func set_mode(mode: int, return_screen: int = UIManager.ScreenName.MAIN_MENU) -> void:
	_mode = mode
	_return_screen = return_screen
	_refresh_header()
	_refresh_slots()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh_header()
		_refresh_slots()


func _refresh_header() -> void:
	if title_label == null:
		return
	title_label.text = "Save Game" if _mode == MenuMode.SAVE else "Load Game"


func _on_back_pressed() -> void:
	if UIManager != null and UIManager.has_method("hide") and UIManager.has_method("show"):
		UIManager.hide(UIManager.ScreenName.LOAD_GAME_MENU)
		UIManager.show(_return_screen)


func _ensure_autosave_row() -> void:
	if autosave_container == null:
		return
	if _autosave_row != null and is_instance_valid(_autosave_row):
		return
	for child in autosave_container.get_children():
		child.queue_free()
	var row := SAVE_SLOT_ROW_SCENE.instantiate() as SaveSlotRow
	if row == null:
		return
	row.name = "AutosaveRow"
	autosave_container.add_child(row)
	_autosave_row = row

	var cb := Callable(self, "_on_autosave_pressed")
	if not row.pressed.is_connected(cb):
		row.pressed.connect(cb)


func _refresh_slots() -> void:
	if slot_list == null:
		return

	for child in slot_list.get_children():
		child.queue_free()

	_ensure_autosave_row()
	_refresh_autosave_row()
	_refresh_manual_slots()
	_refresh_new_slot_button()


func _refresh_autosave_row() -> void:
	if _autosave_row == null or not is_instance_valid(_autosave_row):
		return

	var save_manager = Runtime.save_manager if Runtime != null else null
	if save_manager == null:
		_set_row_data(_autosave_row, "autosave", "Autosave", "", 0, false, false, false)
		return

	var gs: GameSave = save_manager.load_session_game_save()
	var agents: AgentsSave = save_manager.load_session_agents_save()
	var has_save := gs != null
	var detail := ""
	var gold := 0
	if has_save:
		detail = _build_detail_text(gs)
		gold = _get_player_gold(agents)

	var selectable := _mode == MenuMode.LOAD and has_save
	_set_row_data(_autosave_row, "autosave", "Autosave", detail, gold, has_save, selectable, false)


func _refresh_manual_slots() -> void:
	var save_manager = Runtime.save_manager if Runtime != null else null

	_available_slot_ids = []
	var slot_defs: Array[Dictionary] = []
	for i in range(SLOT_IDS.size()):
		var slot_id := SLOT_IDS[i]
		var gs: GameSave = null
		var agents: AgentsSave = null
		var modified := 0
		if save_manager != null:
			gs = save_manager.load_slot_game_save(slot_id)
			agents = save_manager.load_slot_agents_save(slot_id)
			modified = int(save_manager.get_slot_modified_unix(slot_id))

		var has_save := gs != null
		if not has_save:
			_available_slot_ids.append(slot_id)
			continue
		var detail := ""
		var gold := 0
		detail = _build_detail_text(gs)
		gold = _get_player_gold(agents)

		(
			slot_defs
			. append(
				{
					"slot_id": slot_id,
					"index": i,
					"modified": modified,
					"has_save": has_save,
					"detail": detail,
					"gold": gold,
				}
			)
		)

	slot_defs.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a["modified"] == b["modified"]:
				return int(a["index"]) < int(b["index"])
			return int(a["modified"]) > int(b["modified"])
	)

	if slot_defs.is_empty():
		var lbl := Label.new()
		lbl.text = "No saved slots yet."
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(1, 1, 1, 0.7)
		slot_list.add_child(lbl)
		return

	for def in slot_defs:
		var row := SAVE_SLOT_ROW_SCENE.instantiate() as SaveSlotRow
		if row == null:
			continue
		var slot_id: String = def["slot_id"]
		var slot_label := "Slot %d" % (int(def["index"]) + 1)
		var has_save: bool = def["has_save"]
		var detail: String = def["detail"]
		var gold: int = def["gold"]
		var selectable := _mode == MenuMode.SAVE or has_save

		slot_list.add_child(row)
		_set_row_data(row, slot_id, slot_label, detail, gold, has_save, selectable, true)
		row.pressed.connect(func(): _on_slot_selected(slot_id))
		row.delete_requested.connect(_on_delete_requested)


func _refresh_new_slot_button() -> void:
	if new_slot_button == null:
		return
	new_slot_button.visible = _mode == MenuMode.SAVE
	if not new_slot_button.visible:
		return
	var has_space := not _available_slot_ids.is_empty()
	new_slot_button.disabled = not has_space
	new_slot_button.text = "+ New Slot"
	new_slot_button.tooltip_text = "" if has_space else "All slots are full."


func _set_row_data(
	row: SaveSlotRow,
	slot_id: String,
	title: String,
	detail_text: String,
	gold_amount: int,
	save_exists: bool,
	selectable: bool,
	allow_delete: bool
) -> void:
	if row == null:
		return
	if row.is_node_ready():
		row.set_slot_data(
			slot_id, title, detail_text, gold_amount, save_exists, selectable, allow_delete
		)
	else:
		row.call_deferred(
			"set_slot_data",
			slot_id,
			title,
			detail_text,
			gold_amount,
			save_exists,
			selectable,
			allow_delete
		)


func _on_autosave_pressed() -> void:
	if _mode != MenuMode.LOAD:
		return
	if Runtime == null or Runtime.game_flow == null:
		return

	await Runtime.game_flow.load_from_session()


func _on_slot_selected(slot: String) -> void:
	if Runtime == null:
		return

	if _mode == MenuMode.SAVE:
		_save_to_slot(slot)
		return

	if Runtime.game_flow == null:
		return
	await Runtime.game_flow.load_from_slot(slot)


func _on_new_slot_pressed() -> void:
	if _mode != MenuMode.SAVE:
		return
	if _available_slot_ids.is_empty():
		return
	_save_to_slot(_available_slot_ids[0])


func _on_delete_requested(slot_id: String) -> void:
	if Runtime == null or Runtime.save_manager == null:
		return
	var ok = Runtime.save_manager.delete_slot(slot_id)
	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast("Deleted." if ok else "Delete failed.")
	_refresh_slots()


func _save_to_slot(slot_id: String) -> void:
	if Runtime == null:
		return
	var ok := Runtime.save_to_slot(slot_id)
	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast("Saved." if ok else "Save failed.")
	_refresh_slots()


func _build_detail_text(gs: GameSave) -> String:
	if gs == null:
		return ""
	var level_name := _get_level_name(gs.active_level_id)
	var time_text := _format_day_time(gs.current_day, gs.minute_of_day)
	if level_name.is_empty():
		return time_text
	if time_text.is_empty():
		return level_name
	return "%s | %s" % [level_name, time_text]


func _get_level_name(level_id: Enums.Levels) -> String:
	return String(LEVEL_NAMES.get(level_id, "Unknown"))


func _format_day_time(day: int, minute_of_day: int) -> String:
	var day_num := maxi(1, int(day))
	var minutes := maxi(0, int(minute_of_day))
	var hh24 := int(floor(float(minutes) / 60.0)) % 24
	var mm := minutes % 60
	var is_pm := hh24 >= 12
	var hh12 := hh24 % 12
	if hh12 == 0:
		hh12 = 12
	return "Day %d %d:%02d %s" % [day_num, hh12, mm, "pm" if is_pm else "am"]


func _get_player_gold(agents: AgentsSave) -> int:
	if agents == null:
		return 0
	for rec in agents.agents:
		if rec == null:
			continue
		if String(rec.agent_id) == "player":
			return int(rec.money)
	return 0
