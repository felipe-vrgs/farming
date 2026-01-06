class_name LoadingScreen
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

var _tween: Tween = null


func _ready() -> void:
	# Loading overlay must keep working even if the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	color_rect.color.a = 0.0
	color_rect.visible = false


func _input(event: InputEvent) -> void:
	# While the blackout is visible, consume all input to prevent spamming actions
	# during scene transitions.
	if event == null:
		return
	if color_rect != null and color_rect.visible:
		get_viewport().set_input_as_handled()


func fade_out(duration: float = 0.5) -> void:
	if duration <= 0.0:
		color_rect.visible = true
		color_rect.color.a = 1.0
		return
	color_rect.visible = true
	# Prevent a single-frame \"white flash\" where the overlay is visible but still fully transparent.
	color_rect.color.a = maxf(color_rect.color.a, 0.001)
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(color_rect, "color:a", 1.0, duration)
	await _tween.finished


func fade_in(duration: float = 0.5) -> void:
	if duration <= 0.0:
		color_rect.color.a = 0.0
		color_rect.visible = false
		return
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(color_rect, "color:a", 0.0, duration)
	await _tween.finished
	color_rect.visible = false
