extends Node

## UIManager (v0)
## Start of a global UI manager that survives scene changes.
## Owns global UI overlays (menu, pause, loading, debug clock).

enum ScreenName {
	MAIN_MENU = 0,
	LOAD_GAME_MENU = 1,
	PAUSE_MENU = 2,
	LOADING_SCREEN = 3,
	CLOCK = 4
}

const _CLOCK_LABEL_SCENE: PackedScene = preload("res://ui/clock/clock_label.tscn")
const _GAME_MENU_SCENE: PackedScene = preload("res://ui/game_menu/game_menu.tscn")
const _LOAD_GAME_MENU_SCENE: PackedScene = preload("res://ui/game_menu/load_game_menu.tscn")
const _PAUSE_MENU_SCENE: PackedScene = preload("res://ui/pause_menu/pause_menu.tscn")
const _LOADING_SCREEN_SCENE: PackedScene = preload("res://ui/loading_screen/loading_screen.tscn")

const _SCREEN_SCENES: Dictionary[int, PackedScene] = {
	ScreenName.MAIN_MENU: _GAME_MENU_SCENE,
	ScreenName.LOAD_GAME_MENU: _LOAD_GAME_MENU_SCENE,
	ScreenName.PAUSE_MENU: _PAUSE_MENU_SCENE,
	ScreenName.LOADING_SCREEN: _LOADING_SCREEN_SCENE,
	ScreenName.CLOCK: _CLOCK_LABEL_SCENE
}

var _screen_nodes: Dictionary[int, Node] = {
	ScreenName.MAIN_MENU: null,
	ScreenName.LOAD_GAME_MENU: null,
	ScreenName.PAUSE_MENU: null,
	ScreenName.LOADING_SCREEN: null,
	ScreenName.CLOCK: null
}

var _ui_layer: CanvasLayer = null
var _toast_label: Label = null

func _ready() -> void:
	# Keep UI alive while the SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Scene changes happen via GameManager; keep UI in an autoload so it persists.
	call_deferred("_ensure_ui_layer")
	call_deferred("_ensure_clock_overlay")
	# Menu visibility is controlled by GameFlow.

func show(screen: ScreenName) -> Node:
	if screen == null:
		return null
	if screen == ScreenName.CLOCK:
		_ensure_clock_overlay()
		return _screen_nodes[screen]
	var node = show_screen(screen)
	if screen == ScreenName.LOAD_GAME_MENU:
		if node.has_signal("back_pressed"):
			if not node.is_connected("back_pressed", Callable(self, "hide_screen")):
				node.connect("back_pressed", Callable(self, "hide_screen"))

	return node

func hide(screen: int) -> void:
	if screen == null:
		return
	if screen == ScreenName.CLOCK:
		return
	hide_screen(screen)

func _ensure_ui_layer() -> void:
	var root := get_tree().root
	if root == null:
		return

	var existing := root.get_node_or_null(NodePath("UIRoot"))
	if existing is CanvasLayer:
		_ui_layer = existing as CanvasLayer
		return

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UIRoot"
	_ui_layer.layer = 50
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.call_deferred("add_child", _ui_layer)

func _ensure_clock_overlay() -> void:
	var root := get_tree().root
	if root == null:
		return

	var existing := root.get_node_or_null(NodePath("ClockOverlay"))
	if existing is CanvasLayer:
		_screen_nodes[ScreenName.CLOCK] = existing as CanvasLayer
		return

	var overlay = CanvasLayer.new()
	overlay.name = "ClockOverlay"
	overlay.layer = 100
	root.call_deferred("add_child", overlay)

	var n := _SCREEN_SCENES[ScreenName.CLOCK].instantiate()
	if n != null:
		overlay.call_deferred("add_child", n)
	_screen_nodes[ScreenName.CLOCK] = overlay

func show_screen(screen: int) -> Node:
	_ensure_ui_layer()
	if _ui_layer == null:
		return null

	var node := _screen_nodes[screen]
	if node != null and is_instance_valid(node):
		node.visible = true
		return node

	var inst := _SCREEN_SCENES[screen].instantiate()
	if inst == null:
		return null

	_ui_layer.add_child(inst)
	_screen_nodes[screen] = inst
	return inst

func hide_screen(screen: int) -> void:
	var node := _screen_nodes[screen]
	if node != null and is_instance_valid(node):
		node.visible = false

func show_toast(text: String, duration: float = 1.5) -> void:
	_ensure_ui_layer()
	if _ui_layer == null:
		return

	if _toast_label == null or not is_instance_valid(_toast_label):
		_toast_label = Label.new()
		_toast_label.name = "ToastLabel"
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_toast_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_toast_label.anchor_left = 0.0
		_toast_label.anchor_right = 1.0
		_toast_label.anchor_top = 0.0
		_toast_label.anchor_bottom = 0.0
		_toast_label.offset_top = 8.0
		_toast_label.offset_bottom = 32.0
		_toast_label.modulate = Color(1, 1, 1, 1)
		_toast_label.process_mode = Node.PROCESS_MODE_ALWAYS
		_ui_layer.add_child(_toast_label)

	_toast_label.text = text
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(max(0.1, duration))
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		if _toast_label != null and is_instance_valid(_toast_label):
			_toast_label.visible = false
	)
