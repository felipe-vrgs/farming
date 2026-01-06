extends Node

## DayNightManager
## Simple, data-driven world dimming based on TimeManager's clock.
##
## Implementation:
## - Adds a full-screen ColorRect in a CanvasLayer below UI (UIRoot is layer 50).
## - Updates color/alpha based on time-of-day (dawn/dusk ramps).
## - Hides itself in menus (so main menu isn't tinted).

@export var canvas_layer: int = 20

# Times are minutes-of-day in [0..1439].
@export var dawn_start_minute: int = 4 * 60  # 04:00
@export var day_start_minute: int = 7 * 60  # 07:00 (fully bright)
@export var dusk_start_minute: int = 17 * 60  # 17:00
@export var night_start_minute: int = 20 * 60  # 20:00 (fully dark)

@export_range(0.0, 1.0, 0.01) var night_darkness: float = 0.65
@export var night_tint: Color = Color(0.06, 0.08, 0.14, 1.0)

@export var disable_in_interiors: bool = false
@export_range(0.0, 1.0, 0.01) var interior_darkness_mul: float = 0.35
@export var interior_level_ids: Array[int] = [
	int(Enums.Levels.FRIEREN_HOUSE),
	int(Enums.Levels.PLAYER_HOUSE),
]

var _layer: CanvasLayer = null
var _rect: ColorRect = null


func _is_test_mode() -> bool:
	# Headless tests don't need visuals and can report noisy renderer leaks on exit.
	return OS.get_environment("FARMING_TEST_MODE") == "1"


func _ready() -> void:
	if _is_test_mode():
		set_process(false)
		return
	# Keep updating even if the SceneTree is paused (dialogue/pause overlays).
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_init_overlay")


func _process(_delta: float) -> void:
	if _rect == null or not is_instance_valid(_rect):
		return
	if TimeManager == null:
		return

	# Hide in menus (keep the main menu clean).
	if _is_menu_state():
		if _layer != null and is_instance_valid(_layer):
			_layer.visible = false
		return
	if _layer != null and is_instance_valid(_layer) and not _layer.visible:
		_layer.visible = true

	var m := int(TimeManager.get_minute_of_day())
	var a := _alpha_for_minute(m)
	if _is_interior_level():
		if disable_in_interiors:
			a = 0.0
		else:
			a *= clampf(interior_darkness_mul, 0.0, 1.0)
	var c := Color(night_tint.r, night_tint.g, night_tint.b, a)

	# Avoid spamming property updates if unchanged.
	if _rect.color.is_equal_approx(c):
		return
	_rect.color = c


func _init_overlay() -> void:
	var root := get_tree().root
	if root == null:
		return

	var existing_layer := root.get_node_or_null(NodePath("DayNightLayer"))
	if existing_layer is CanvasLayer:
		_layer = existing_layer as CanvasLayer
		_rect = _layer.get_node_or_null(NodePath("DayNightRect")) as ColorRect
		return

	_layer = CanvasLayer.new()
	_layer.name = "DayNightLayer"
	_layer.layer = int(canvas_layer)
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_layer)

	_rect = ColorRect.new()
	_rect.name = "DayNightRect"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.anchor_left = 0.0
	_rect.anchor_right = 1.0
	_rect.anchor_top = 0.0
	_rect.anchor_bottom = 1.0
	_rect.offset_left = 0.0
	_rect.offset_right = 0.0
	_rect.offset_top = 0.0
	_rect.offset_bottom = 0.0
	_rect.color = Color(night_tint.r, night_tint.g, night_tint.b, 0.0)
	_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_child(_rect)


func _is_menu_state() -> bool:
	if Runtime == null or Runtime.game_flow == null:
		return false
	var gf: Node = Runtime.game_flow
	# Avoid direct property access on a generic Node; use Object.get().
	var state_v: Variant = gf.get("state")
	if state_v is StringName:
		var st: StringName = state_v
		return st == GameStateNames.MENU or st == GameStateNames.BOOT
	return false


func _is_interior_level() -> bool:
	if Runtime == null or not Runtime.has_method("get_active_level_id"):
		return false
	var level_id := int(Runtime.call("get_active_level_id"))
	return interior_level_ids.has(level_id)


func _alpha_for_minute(minute_of_day: int) -> float:
	var m := clampi(minute_of_day, 0, TimeManager.MINUTES_PER_DAY - 1)

	# Day window: fully bright.
	if m >= day_start_minute and m < dusk_start_minute:
		return 0.0

	# Dusk ramp: 0 -> night_darkness.
	if m >= dusk_start_minute and m < night_start_minute:
		var t := (
			float(m - dusk_start_minute) / float(maxi(1, night_start_minute - dusk_start_minute))
		)
		return _smoothstep(0.0, night_darkness, t)

	# Dawn ramp: night_darkness -> 0.
	if m >= dawn_start_minute and m < day_start_minute:
		var t := float(m - dawn_start_minute) / float(maxi(1, day_start_minute - dawn_start_minute))
		return _smoothstep(night_darkness, 0.0, t)

	# Night window (wrap-around): fully dark.
	return night_darkness


static func _smoothstep(a: float, b: float, t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	x = x * x * (3.0 - 2.0 * x)
	return lerpf(a, b, x)
