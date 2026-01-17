class_name EmoteBubble
extends Control

signal expired

@onready var _icon: TextureRect = %Icon
@onready var _text: Label = %Text
@onready var _panel: PanelContainer = %BubblePanel

var _timer: Timer = null
var _show_tween: Tween = null
var _hide_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()


func set_content(
	icon: Texture2D,
	text: String,
	duration: float,
	show_text: bool = true,
	show_panel: bool = true,
	scale_factor: float = 1.0
) -> void:
	if _icon != null:
		_icon.texture = icon
		_icon.visible = icon != null
	if _text != null:
		var t := String(text).strip_edges()
		_text.text = t
		_text.visible = show_text and not t.is_empty()

	_base_scale = Vector2.ONE * maxf(0.5, float(scale_factor))
	_apply_panel_style(show_panel)
	_refresh_layout()
	_show()

	if duration > 0.0:
		_start_timer(duration)
	else:
		_stop_timer()


func dismiss() -> void:
	_stop_timer()
	_hide()


func _start_timer(duration: float) -> void:
	if _timer == null or not is_instance_valid(_timer):
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_timer)
		_timer.timeout.connect(_on_timeout)
	_timer.start(maxf(0.01, duration))


func _stop_timer() -> void:
	if _timer != null and is_instance_valid(_timer):
		_timer.stop()


func _show() -> void:
	if _hide_tween != null and is_instance_valid(_hide_tween):
		_hide_tween.kill()
		_hide_tween = null
	if _show_tween != null and is_instance_valid(_show_tween):
		_show_tween.kill()
		_show_tween = null

	visible = true
	modulate.a = 0.0
	scale = _base_scale * 0.9

	_show_tween = create_tween()
	_show_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_show_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_show_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	_show_tween.parallel().tween_property(self, "scale", _base_scale, 0.12)


func _hide() -> void:
	if not visible:
		return
	if _show_tween != null and is_instance_valid(_show_tween):
		_show_tween.kill()
		_show_tween = null
	if _hide_tween != null and is_instance_valid(_hide_tween):
		_hide_tween.kill()

	_hide_tween = create_tween()
	_hide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hide_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hide_tween.tween_property(self, "modulate:a", 0.0, 0.10)
	_hide_tween.parallel().tween_property(self, "scale", _base_scale * 0.9, 0.10)
	_hide_tween.finished.connect(
		func() -> void:
			visible = false
			expired.emit()
	)


func _refresh_layout() -> void:
	await get_tree().process_frame
	if _panel != null:
		var min_size := _panel.get_combined_minimum_size()
		_panel.size = min_size
		_panel.position = Vector2.ZERO
		size = min_size
	pivot_offset = size * Vector2(0.5, 1.0)


func get_anchor_offset() -> Vector2:
	return size * Vector2(0.5, 1.0)


func _apply_style() -> void:
	_apply_panel_style(true)
	if _text != null:
		_text.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
		_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_text.add_theme_constant_override("outline_size", 1)


func _apply_panel_style(show_panel: bool) -> void:
	if _panel == null:
		return
	_panel.theme = null
	var box := StyleBoxFlat.new()
	if show_panel:
		box.bg_color = Color(0.08, 0.08, 0.1, 0.72)
		box.border_width_left = 1
		box.border_width_right = 1
		box.border_width_top = 1
		box.border_width_bottom = 1
		box.border_color = Color(0.78, 0.8, 0.86, 0.85)
		box.corner_radius_top_left = 4
		box.corner_radius_top_right = 4
		box.corner_radius_bottom_left = 4
		box.corner_radius_bottom_right = 4
	else:
		box.bg_color = Color(0, 0, 0, 0)
		box.border_width_left = 0
		box.border_width_right = 0
		box.border_width_top = 0
		box.border_width_bottom = 0
		box.corner_radius_top_left = 0
		box.corner_radius_top_right = 0
		box.corner_radius_bottom_left = 0
		box.corner_radius_bottom_right = 0
	_panel.add_theme_stylebox_override("panel", box)


func _on_timeout() -> void:
	_hide()
