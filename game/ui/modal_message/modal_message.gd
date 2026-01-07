class_name ModalMessage
extends CanvasLayer

## Simple blocking modal with an OK button.
## Designed to render above LoadingScreen (layer 100).

signal confirmed

const _UI_THEME: Theme = preload("res://game/ui/theme/ui_theme.tres")

@onready var _panel: PanelContainer = $Root/Panel
@onready var _label: Label = $Root/Panel/Margin/VBox/Message
@onready var _ok_button: Button = $Root/Panel/Margin/VBox/OkButton


func _ready() -> void:
	# Must work while the SceneTree is paused / in blackout.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(Groups.MODAL)
	if _panel != null:
		_panel.theme = _UI_THEME
	# Ensure modal captures input.
	if $Root != null:
		($Root as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	if _ok_button != null and not _ok_button.pressed.is_connected(_on_ok_pressed):
		_ok_button.pressed.connect(_on_ok_pressed)
	_ok_button.grab_focus.call_deferred()


func set_message(text: String) -> void:
	if _label != null:
		_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	# Allow keyboard/gamepad accept.
	if (
		event != null
		and (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"))
	):
		get_viewport().set_input_as_handled()
		_on_ok_pressed()


func _on_ok_pressed() -> void:
	confirmed.emit()
	queue_free()
