class_name DebugGrid
extends Node2D

var _font: Font
var _modules: Array[DebugGridModule] = []
var _grid_module: GridDebugModule

@onready var _timer: Timer = $Timer


func _ready() -> void:
	# Debug-only. This scene is autoloaded for convenience, but should not exist in
	# release builds or headless test runs.
	if not OS.is_debug_build() or OS.get_environment("FARMING_TEST_MODE") == "1":
		set_process(false)
		set_process_input(false)
		visible = false
		queue_free()
		return

	visible = false
	z_index = 100  # Draw on top
	_font = ThemeDB.fallback_font

	# Create HUD for global/offline info
	_create_hud()

	# Register Modules
	_grid_module = _load_module(GridDebugModule.new()) as GridDebugModule
	_load_module(MarkerDebugModule.new())
	_load_module(AgentDebugModule.new())

	# Polling for grid updates every second
	_timer.timeout.connect(_on_poll_timer_timeout)


func _load_module(mod: DebugGridModule) -> DebugGridModule:
	mod.setup(self, _font)
	_modules.append(mod)
	return mod


func is_grid_enabled() -> bool:
	return _grid_module != null and _grid_module.is_enabled()


func set_grid_enabled(enabled: bool) -> void:
	if _grid_module == null:
		return
	_grid_module.set_enabled(enabled)
	queue_redraw()


func _create_hud() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "DebugGridHUD"
	canvas.layer = 101  # Above debug grid
	add_child(canvas)

	var label = Label.new()
	label.name = "InfoLabel"
	label.position = Vector2(10, 50)
	label.add_theme_font_size_override("font_size", 8)
	label.modulate = Color(1, 1, 1, 0.8)
	canvas.add_child(label)
	canvas.visible = false


func _update_hud() -> void:
	var canvas = get_node_or_null("DebugGridHUD")
	if not canvas:
		return

	var any_hud := false
	var lines: Array[String] = []
	for mod in _modules:
		mod._update_hud(lines)
		if mod is AgentDebugModule and (mod as AgentDebugModule).is_hud_enabled():
			any_hud = true

	canvas.visible = any_hud
	if not any_hud:
		return

	var label = canvas.get_node_or_null("InfoLabel")
	if not label:
		return
	label.text = "\n".join(lines)


func _on_poll_timer_timeout() -> void:
	queue_redraw()
	_update_hud()
	for mod in _modules:
		mod._on_poll_timer_timeout()


func _input(event: InputEvent) -> void:
	for mod in _modules:
		mod._input(event)

	# Global visibility control
	var any_enabled := false
	for mod in _modules:
		if mod.has_method("is_enabled") and mod.is_enabled():
			any_enabled = true
			break
	visible = any_enabled
	_update_hud()


func _draw() -> void:
	var tile_size := Vector2(16, 16)
	for mod in _modules:
		mod._draw(tile_size)


func _get_enum_string(enum_dict: Dictionary, value: int) -> String:
	var k = enum_dict.find_key(value)
	return k if k != null else str(value)
