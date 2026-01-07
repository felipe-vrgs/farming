extends Node

## UIManager (v0)
## Start of a global UI manager that survives scene changes.
## Owns global UI overlays (menu, pause, loading, debug clock).

enum ScreenName {
	MAIN_MENU = 0,
	LOAD_GAME_MENU = 1,
	PAUSE_MENU = 2,
	LOADING_SCREEN = 3,
	VIGNETTE = 4,
	HUD = 5,
	PLAYER_MENU = 6,
	SHOP_MENU = 7,
}

const _GAME_MENU_SCENE: PackedScene = preload("res://game/ui/game_menu/game_menu.tscn")
const _LOAD_GAME_MENU_SCENE: PackedScene = preload("res://game/ui/game_menu/load_game_menu.tscn")
const _PAUSE_MENU_SCENE: PackedScene = preload("res://game/ui/pause_menu/pause_menu.tscn")
const _LOADING_SCREEN_SCENE: PackedScene = preload(
	"res://game/ui/loading_screen/loading_screen.tscn"
)
const _VIGNETTE_SCENE: PackedScene = preload("res://game/ui/vignette/vignette.tscn")
const _HUD_SCENE: PackedScene = preload("res://game/ui/hud/hud.tscn")
const _PLAYER_MENU_SCENE: PackedScene = preload("res://game/ui/player_menu/player_menu.tscn")
const _SHOP_MENU_SCENE: PackedScene = preload("res://game/ui/shop/shop_menu.tscn")

const _UI_ROOT_LAYER := 50
# Any UI screen scene that is itself a CanvasLayer must render above world overlays (day/night, etc)
const _CANVAS_UI_MIN_LAYER := 60

const _SCREEN_SCENES: Dictionary[int, PackedScene] = {
	ScreenName.MAIN_MENU: _GAME_MENU_SCENE,
	ScreenName.LOAD_GAME_MENU: _LOAD_GAME_MENU_SCENE,
	ScreenName.PAUSE_MENU: _PAUSE_MENU_SCENE,
	ScreenName.LOADING_SCREEN: _LOADING_SCREEN_SCENE,
	ScreenName.VIGNETTE: _VIGNETTE_SCENE,
	ScreenName.HUD: _HUD_SCENE,
	ScreenName.PLAYER_MENU: _PLAYER_MENU_SCENE,
	ScreenName.SHOP_MENU: _SHOP_MENU_SCENE,
}

var _screen_nodes: Dictionary[int, Node] = {
	ScreenName.MAIN_MENU: null,
	ScreenName.LOAD_GAME_MENU: null,
	ScreenName.PAUSE_MENU: null,
	ScreenName.LOADING_SCREEN: null,
	ScreenName.VIGNETTE: null,
	ScreenName.HUD: null,
	ScreenName.PLAYER_MENU: null,
	ScreenName.SHOP_MENU: null,
}

var _ui_layer: CanvasLayer = null
var _toast_label: Label = null
var _loading_screen_refcount: int = 0
var _blackout_depth: int = 0


func _ready() -> void:
	# Keep UI alive while the SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Scene changes happen via runtime services; keep UI in an autoload so it persists.
	call_deferred("_ensure_ui_layer")
	# Menu visibility is controlled by Runtime-owned GameFlow.


func show(screen: ScreenName) -> Node:
	# Some screens "replace" others.
	if screen == ScreenName.LOAD_GAME_MENU:
		# Prevent two full-screen menus fighting for attention.
		hide(ScreenName.MAIN_MENU)

	var node := show_screen(int(screen))
	if node != null:
		_bring_to_front(node)

	return node


## Acquire the global loading screen overlay (reference counted).
## This prevents flicker when multiple systems fade around the same time.
func acquire_loading_screen() -> LoadingScreen:
	_loading_screen_refcount += 1
	var node := show(ScreenName.LOADING_SCREEN)
	return node as LoadingScreen


## Release the loading screen overlay acquired by acquire_loading_screen().
func release_loading_screen() -> void:
	_loading_screen_refcount = maxi(0, _loading_screen_refcount - 1)
	if _loading_screen_refcount > 0:
		return
	hide(ScreenName.LOADING_SCREEN)


## Begin a nested blackout transaction (fade to black and keep it black).
## Reference-counted: only the first call performs the fade-out.
func blackout_begin(time: float = 0.25) -> void:
	_blackout_depth += 1
	if _blackout_depth != 1:
		return

	var loading := acquire_loading_screen()
	if loading == null:
		# Roll back so we don't get stuck "in blackout".
		_blackout_depth = 0
		return
	await loading.fade_out(maxf(0.0, time))


## End a nested blackout transaction (fade back in and release overlay).
## Reference-counted: only the last call performs the fade-in.
func blackout_end(time: float = 0.25) -> void:
	_blackout_depth = maxi(0, _blackout_depth - 1)
	if _blackout_depth != 0:
		return

	var loading: LoadingScreen = null
	if has_method("get_screen_node"):
		loading = get_screen_node(ScreenName.LOADING_SCREEN) as LoadingScreen
	if loading != null:
		await loading.fade_in(maxf(0.0, time))
	release_loading_screen()


func get_screen_node(screen: ScreenName) -> Node:
	# Returns the node even if it is currently hidden (visible = false).
	return _screen_nodes.get(int(screen)) as Node


func hide(screen: ScreenName) -> void:
	hide_screen(int(screen))


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
	_ui_layer.layer = _UI_ROOT_LAYER
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.call_deferred("add_child", _ui_layer)


func show_screen(screen: int) -> Node:
	var node := _screen_nodes[screen]
	if node != null and is_instance_valid(node):
		node.visible = true
		_bring_to_front(node)
		if node.has_method("rebind"):
			if screen == ScreenName.HUD:
				node.call("rebind")
			elif screen == ScreenName.PLAYER_MENU:
				var p: Player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
				node.call("rebind", p)
		return node

	var inst := _SCREEN_SCENES[screen].instantiate()
	if inst == null:
		return null

	# CanvasLayer screens should attach to the root, not under UIRoot (also a CanvasLayer).
	if inst is CanvasLayer:
		# Ensure CanvasLayer UI screens are always above any "world overlay" CanvasLayers
		# (e.g., day/night lighting), and keep any explicit high layer (loading screen is 100).
		var cl := inst as CanvasLayer
		cl.layer = maxi(int(cl.layer), _CANVAS_UI_MIN_LAYER)
		get_tree().root.add_child(inst)
	else:
		_ensure_ui_layer()
		if _ui_layer == null:
			inst.queue_free()
			return null
		_ui_layer.add_child(inst)

	_screen_nodes[screen] = inst
	if inst.has_method("rebind"):
		if screen == ScreenName.HUD:
			inst.call("rebind")
		elif screen == ScreenName.PLAYER_MENU:
			var p: Player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			inst.call("rebind", p)
	_bring_to_front(inst)
	return inst


func _bring_to_front(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var p := node.get_parent()
	if p == null:
		return
	p.move_child(node, p.get_child_count() - 1)


func rebind_hud(player: Player = null) -> void:
	var node: Node = _screen_nodes.get(ScreenName.HUD) as Node
	if node != null and is_instance_valid(node) and node.has_method("rebind"):
		node.call("rebind", player)


func hide_screen(screen: int) -> void:
	var node := _screen_nodes[screen]
	if node != null and is_instance_valid(node):
		node.visible = false


func hide_all_menus() -> void:
	hide(ScreenName.PAUSE_MENU)
	hide(ScreenName.LOAD_GAME_MENU)
	hide(ScreenName.MAIN_MENU)
	hide(ScreenName.PLAYER_MENU)
	hide(ScreenName.SHOP_MENU)
	hide(ScreenName.HUD)


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
	tween.finished.connect(
		func():
			if _toast_label != null and is_instance_valid(_toast_label):
				_toast_label.visible = false
	)
