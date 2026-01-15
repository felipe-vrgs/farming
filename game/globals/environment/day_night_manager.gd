extends Node

## DayNightManager
## Simple, data-driven world dimming based on TimeManager's clock.
##
## Implementation:
## - Adds a CanvasModulate to tint the world (lights remain visible).
## - Updates color based on time-of-day (dawn/dusk ramps).
## - Hides itself in menus (so main menu isn't tinted).

@export var canvas_layer: int = 20

# Times are minutes-of-day in [0..1439].
@export var dawn_start_minute: int = 4 * 60  # 04:00
@export var day_start_minute: int = 8 * 60  # 08:00 (fully bright)
@export var dusk_start_minute: int = 17 * 60  # 17:00
@export var night_start_minute: int = 21 * 60  # 21:00 (fully dark)

@export_range(0.0, 1.0, 0.01) var night_darkness: float = 0.9
@export var night_tint: Color = Color(0.05, 0.07, 0.14, 1)

@export var disable_in_interiors: bool = false
@export_range(0.0, 1.0, 0.01) var interior_darkness_mul: float = 0.75
@export var interior_level_ids: Array[int] = [
	int(Enums.Levels.FRIEREN_HOUSE),
	int(Enums.Levels.PLAYER_HOUSE),
]

var _modulate: CanvasModulate = null
var _night_mode_mul: float = 1.0


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
	if _modulate == null or not is_instance_valid(_modulate):
		return
	if TimeManager == null:
		return

	# Hide in menus (keep the main menu clean).
	if _is_menu_state():
		_modulate.color = Color(1, 1, 1, 1)
		return

	var m := int(TimeManager.get_minute_of_day())
	var a := _alpha_for_minute(m)
	if _is_interior_level():
		if disable_in_interiors:
			a = 0.0
		else:
			a *= clampf(interior_darkness_mul, 0.0, 1.0)
	a = clampf(a * _night_mode_mul, 0.0, 1.0)
	var c := _tint_for_darkness(a, night_tint)

	# Avoid spamming property updates if unchanged.
	if _modulate.color.is_equal_approx(c):
		return
	_modulate.color = c


func set_night_mode_multiplier(multiplier: float) -> void:
	# Safety clamp so night mode doesn't crush lighting entirely.
	_night_mode_mul = clampf(multiplier, 0.0, 4.0)


func clear_night_mode_multiplier() -> void:
	_night_mode_mul = 1.0


func _tint_for_darkness(darkness: float, tint: Color) -> Color:
	var d := clampf(darkness, 0.0, 1.0)
	var r := lerpf(1.0, tint.r, d)
	var g := lerpf(1.0, tint.g, d)
	var b := lerpf(1.0, tint.b, d)
	return Color(r, g, b, 1.0)


func _init_overlay() -> void:
	var root := get_tree().root
	if root == null:
		return

	var existing_layer := root.get_node_or_null(NodePath("DayNightLayer"))
	if existing_layer is CanvasLayer:
		existing_layer.queue_free()

	var existing := root.get_node_or_null(NodePath("DayNightModulate"))
	if existing is CanvasModulate:
		_modulate = existing as CanvasModulate
		return

	_modulate = CanvasModulate.new()
	_modulate.name = "DayNightModulate"
	_modulate.process_mode = Node.PROCESS_MODE_ALWAYS
	_modulate.color = Color(1, 1, 1, 1)
	root.add_child(_modulate)


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
