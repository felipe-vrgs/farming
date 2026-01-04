class_name VignetteOverlay
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

var _tween: Tween = null

func _ready() -> void:
	# Keep UI alive while the SceneTree is paused (dialogue mode).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_alpha(0.0)
	visible = false

func fade_in(duration: float = 0.25) -> void:
	visible = true
	_start_tween(_get_alpha(), 1.0, duration)

func fade_out(duration: float = 0.25) -> void:
	_start_tween(_get_alpha(), 0.0, duration, true)

func _start_tween(
	from_a: float,
	to_a: float,
	duration: float,
	hide_when_done: bool = false
) -> void:
	if duration <= 0.0:
		return
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(
		_set_alpha,
		from_a,
		to_a,
		maxf(0.0, duration)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if hide_when_done:
		_tween.finished.connect(func() -> void:
			if is_inside_tree():
				visible = false
		)

func _get_alpha() -> float:
	if color_rect == null:
		return 0.0
	var mat := color_rect.material as ShaderMaterial
	if mat == null:
		return 0.0
	return float(mat.get_shader_parameter("alpha_mul"))

func _set_alpha(a: float) -> void:
	if color_rect == null:
		return
	var mat := color_rect.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("alpha_mul", clampf(a, 0.0, 1.0))

