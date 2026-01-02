extends Control

@onready var slot_list: VBoxContainer = $CenterContainer/VBoxContainer/ScrollContainer/SlotList
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_refresh_slots()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh_slots()

func _on_back_pressed() -> void:
	# This screen owns its own actions.
	if UIManager != null and UIManager.has_method("hide") and UIManager.has_method("show"):
		UIManager.hide(UIManager.ScreenName.LOAD_GAME_MENU)
		UIManager.show(UIManager.ScreenName.MAIN_MENU)

func _refresh_slots() -> void:
	if not slot_list:
		return

	for child in slot_list.get_children():
		child.queue_free()

	if not Runtime or Runtime.save_manager == null:
		return

	var slots = Runtime.save_manager.list_slots()
	if slots.is_empty():
		var lbl = Label.new()
		lbl.text = "No saved games found."
		lbl.add_theme_font_size_override("font_size", 12)
		slot_list.add_child(lbl)
		return

	for slot in slots:
		var btn = Button.new()
		btn.text = slot
		btn.custom_minimum_size = Vector2(180, 25)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): _on_slot_selected(slot))
		slot_list.add_child(btn)

func _on_slot_selected(slot: String) -> void:
	if Runtime and Runtime.game_flow != null:
		await Runtime.game_flow.load_from_slot(slot)

