extends Control

signal back_pressed

@onready var slot_list: VBoxContainer = $CenterContainer/VBoxContainer/ScrollContainer/SlotList
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_refresh_slots()

func _on_back_pressed() -> void:
	back_pressed.emit()
	queue_free()

func _refresh_slots() -> void:
	if not slot_list:
		return

	for child in slot_list.get_children():
		child.queue_free()

	if not SaveManager:
		return

	var slots = SaveManager.list_slots()
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
	if GameManager:
		# loading handles scene change
		GameManager.load_from_slot(slot)

