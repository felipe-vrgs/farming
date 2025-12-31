extends Node

## UIManager (v0)
## Start of a global UI manager that survives scene changes.
## For now, it owns the debug clock overlay.

const _CLOCK_LABEL_SCENE: PackedScene = preload("res://ui/clock/clock_label.tscn")

var _clock_overlay: CanvasLayer = null

func _ready() -> void:
	# Scene changes happen via GameManager; keep UI in an autoload so it persists.
	call_deferred("_ensure_clock_overlay")

func _ensure_clock_overlay() -> void:
	var root := get_tree().root
	if root == null:
		return

	var existing := root.get_node_or_null(NodePath("ClockOverlay"))
	if existing is CanvasLayer:
		_clock_overlay = existing as CanvasLayer
		return

	_clock_overlay = CanvasLayer.new()
	_clock_overlay.name = "ClockOverlay"
	_clock_overlay.layer = 100
	root.call_deferred("add_child", _clock_overlay)

	if _CLOCK_LABEL_SCENE != null:
		var n := _CLOCK_LABEL_SCENE.instantiate()
		if n != null:
			_clock_overlay.call_deferred("add_child", n)

