class_name LoadingScreen
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	color_rect.color.a = 0.0
	color_rect.visible = false

func fade_out(duration: float = 0.5) -> void:
	color_rect.visible = true
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
	color_rect.visible = false

