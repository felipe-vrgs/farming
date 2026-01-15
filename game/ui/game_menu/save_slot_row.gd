class_name SaveSlotRow
extends Button

signal delete_requested(slot_id: String)

@onready var slot_label: Label = %SlotLabel
@onready var detail_label: Label = %DetailLabel
@onready var empty_label: Label = %EmptyLabel
@onready var gold_label: Label = %GoldLabel
@onready var delete_button: Button = %DeleteButton

var slot_id: String = ""
var has_save: bool = false


func _ready() -> void:
	if delete_button != null:
		delete_button.mouse_filter = Control.MOUSE_FILTER_STOP
		delete_button.pressed.connect(_on_delete_pressed)


func set_slot_data(
	slot_id_in: String,
	title: String,
	detail_text: String,
	gold_amount: int,
	save_exists: bool,
	selectable: bool,
	allow_delete: bool = false
) -> void:
	slot_id = slot_id_in
	has_save = save_exists

	if slot_label != null:
		slot_label.text = title

	if save_exists:
		if detail_label != null:
			detail_label.text = detail_text
			detail_label.visible = true
		if gold_label != null:
			gold_label.text = "Gold: %d" % gold_amount
			gold_label.visible = true
		if empty_label != null:
			empty_label.visible = false
	else:
		if detail_label != null:
			detail_label.visible = false
		if gold_label != null:
			gold_label.visible = false
		if empty_label != null:
			empty_label.visible = true

	if delete_button != null:
		delete_button.visible = allow_delete
		delete_button.disabled = not allow_delete

	disabled = not selectable


func _on_delete_pressed() -> void:
	delete_requested.emit(slot_id)
