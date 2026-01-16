class_name ModalConfirm
extends CanvasLayer

## Simple blocking modal with Yes/No buttons.
## Designed to render above LoadingScreen/ModalMessage (layer 110).

signal decided(accepted: bool)

const _UI_THEME: Theme = preload("res://game/ui/theme/ui_theme.tres")
const _MIN_PANEL_WIDTH := 220.0
const _MAX_TEXT_WIDTH := 260.0

@onready var _panel: PanelContainer = $Root/Panel
@onready var _content: HBoxContainer = $Root/Panel/Margin/VBox/Content
@onready var _label: Label = $Root/Panel/Margin/VBox/Content/Message
@onready var _slot_panel: PanelContainer = $Root/Panel/Margin/VBox/Content/ItemSlot
@onready var _icon_rect: TextureRect = $Root/Panel/Margin/VBox/Content/ItemSlot/Icon
@onready var _count_label: Label = $Root/Panel/Margin/VBox/Content/ItemSlot/Count
@onready var _yes_button: Button = $Root/Panel/Margin/VBox/Buttons/YesButton
@onready var _no_button: Button = $Root/Panel/Margin/VBox/Buttons/NoButton

var _pending_message: String = ""
var _pending_yes_label: String = ""
var _pending_no_label: String = ""
var _pending_icon: Texture2D = null
var _pending_count: int = 0


func _ready() -> void:
	# Must work while the SceneTree is paused / in blackout.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(Groups.MODAL)
	if _panel != null:
		_panel.theme = _UI_THEME
	# Ensure modal captures input.
	if $Root != null:
		($Root as Control).mouse_filter = Control.MOUSE_FILTER_STOP

	if _yes_button != null and not _yes_button.pressed.is_connected(_on_yes_pressed):
		_yes_button.pressed.connect(_on_yes_pressed)
	if _no_button != null and not _no_button.pressed.is_connected(_on_no_pressed):
		_no_button.pressed.connect(_on_no_pressed)

	if _label != null:
		_label.custom_minimum_size.x = _MAX_TEXT_WIDTH
	if _content != null:
		_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if not _pending_message.is_empty():
		set_message(_pending_message)
	if not _pending_yes_label.is_empty() or not _pending_no_label.is_empty():
		set_labels(_pending_yes_label, _pending_no_label)
	if _pending_icon != null:
		set_icon(_pending_icon)
	if _pending_count > 0:
		set_count(_pending_count)

	_yes_button.grab_focus.call_deferred()
	_reflow.call_deferred()


func set_message(text: String) -> void:
	if _label == null:
		_pending_message = text
		return
	if _label != null:
		_label.text = text
	_reflow.call_deferred()


func set_labels(yes_text: String = "Yes", no_text: String = "No") -> void:
	if _yes_button == null or _no_button == null:
		_pending_yes_label = yes_text
		_pending_no_label = no_text
		return
	if _yes_button != null and not yes_text.is_empty():
		_yes_button.text = yes_text
	if _no_button != null and not no_text.is_empty():
		_no_button.text = no_text
	_reflow.call_deferred()


func set_icon(icon: Texture2D) -> void:
	if _icon_rect == null or _slot_panel == null:
		_pending_icon = icon
		return
	_icon_rect.texture = icon
	_icon_rect.visible = icon != null
	_slot_panel.visible = icon != null
	_reflow.call_deferred()


func set_count(count: int) -> void:
	if _count_label == null:
		_pending_count = count
		return
	var c := maxi(0, int(count))
	_count_label.visible = c > 1
	_count_label.text = "x%d" % c if c > 1 else ""
	_reflow.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event == null:
		return
	# Keyboard/gamepad:
	# - Accept => Yes
	# - Cancel => No
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_on_yes_pressed()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_no_pressed()


func _on_yes_pressed() -> void:
	decided.emit(true)
	queue_free()


func _on_no_pressed() -> void:
	decided.emit(false)
	queue_free()


func _reflow() -> void:
	if _panel == null or $Root == null:
		return
	var root := $Root as Control
	if root == null:
		return
	# Ensure icon hides cleanly when not set.
	if _slot_panel != null:
		_slot_panel.visible = _icon_rect != null and _icon_rect.texture != null
	var min_size := _panel.get_combined_minimum_size()
	min_size.x = maxf(min_size.x, _MIN_PANEL_WIDTH)
	_panel.size = min_size
	_panel.position = (root.size - _panel.size) * 0.5
