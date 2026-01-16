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

@export_group("Weather")
@export var rain_day_tint: Color = Color(0.6, 0.65, 0.7, 1.0)
@export_range(0.0, 1.0, 0.01) var rain_day_strength: float = 0.6
@export_range(0.0, 1.0, 0.01) var rain_day_darkness: float = 0.12
@export_range(0.1, 10.0, 0.1) var rain_blend_speed: float = 2.5

@export var disable_in_interiors: bool = false
@export_range(0.0, 1.0, 0.01) var interior_darkness_mul: float = 0.75
@export var interior_level_ids: Array[int] = [
	int(Enums.Levels.FRIEREN_HOUSE),
	int(Enums.Levels.PLAYER_HOUSE),
]

var _modulate: CanvasModulate = null
var _night_mode_mul: float = 1.0
var _rain_mode: bool = false
var _rain_strength_current: float = 0.0
var _rain_strength_target: float = 0.0
var _light_manager: LightManager = null
var _flow_connected: bool = false
var _last_non_loading_base_state: StringName = &""


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
	call_deferred("_ensure_light_manager")
	call_deferred("_try_connect_flow")


func _process(_delta: float) -> void:
	_try_connect_flow()
	if _modulate == null or not is_instance_valid(_modulate):
		return
	if TimeManager == null:
		return

	# Hide in menus (keep the main menu clean).
	if _is_menu_state():
		_modulate.color = Color(1, 1, 1, 1)
		_apply_menu_hidden(true)
		return
	_apply_menu_hidden(false)

	var m := int(TimeManager.get_minute_of_day())
	_rain_strength_current = _step_towards(
		_rain_strength_current, _rain_strength_target, rain_blend_speed * _delta
	)
	var a := _compute_darkness_alpha(m)
	var c := _compute_color_for_minute(m)
	_apply_light_darkness(a)
	_apply_rain_strength(_rain_strength_current)

	# Avoid spamming property updates if unchanged.
	if _modulate.color.is_equal_approx(c):
		return
	_modulate.color = c


func set_night_mode_multiplier(multiplier: float) -> void:
	# Safety clamp so night mode doesn't crush lighting entirely.
	_night_mode_mul = clampf(multiplier, 0.0, 4.0)


func clear_night_mode_multiplier() -> void:
	_night_mode_mul = 1.0


func set_rain_mode(enabled: bool, strength: float = -1.0) -> void:
	_rain_mode = enabled
	if strength >= 0.0:
		rain_day_strength = clampf(strength, 0.0, 1.0)
	_rain_strength_target = 1.0 if _rain_mode else 0.0


func _compute_color_for_minute(minute_of_day: int) -> Color:
	var a := _compute_darkness_alpha(minute_of_day)
	var c := _tint_for_darkness(a, night_tint)
	if _rain_mode:
		var night_max := maxf(night_darkness, 0.001)
		var day_mix := 1.0 - clampf(a / night_max, 0.0, 1.0)
		if day_mix > 0.0:
			var tint_strength := (
				clampf(rain_day_strength, 0.0, 1.0) * _rain_strength_current * day_mix
			)
			var dark_strength := (
				clampf(rain_day_darkness, 0.0, 1.0) * _rain_strength_current * day_mix
			)
			c = c.lerp(rain_day_tint, tint_strength)
			c = c.darkened(dark_strength)
	return c


static func _step_towards(current: float, target: float, step: float) -> float:
	if current == target:
		return current
	if step <= 0.0:
		return target
	if current < target:
		return minf(current + step, target)
	return maxf(current - step, target)


func _tint_for_darkness(darkness: float, tint: Color) -> Color:
	var d := clampf(darkness, 0.0, 1.0)
	var r := lerpf(1.0, tint.r, d)
	var g := lerpf(1.0, tint.g, d)
	var b := lerpf(1.0, tint.b, d)
	return Color(r, g, b, 1.0)


func get_darkness_alpha(minute_of_day: int = -1) -> float:
	var m := minute_of_day
	if m < 0 and TimeManager != null:
		m = int(TimeManager.get_minute_of_day())
	return _compute_darkness_alpha(m)


func _compute_darkness_alpha(minute_of_day: int) -> float:
	var a := _alpha_for_minute(minute_of_day)
	if _is_interior_level():
		if disable_in_interiors:
			a = 0.0
		else:
			a *= clampf(interior_darkness_mul, 0.0, 1.0)
	a = clampf(a * _night_mode_mul, 0.0, 1.0)
	return a


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
	var state_v: Variant = null
	if gf.has_method("get_base_state"):
		state_v = gf.call("get_base_state")
	else:
		state_v = gf.get("base_state")
	if state_v is StringName:
		var st: StringName = state_v
		return st == GameStateNames.MENU or st == GameStateNames.BOOT
	return false


func register_light(light: Node) -> void:
	_ensure_light_manager()
	_sync_light_manager_state()
	if _light_manager != null:
		_light_manager.register_light(light)


func unregister_light(light: Node) -> void:
	if _light_manager != null:
		_light_manager.unregister_light(light)


func push_lighting_override(token: StringName, data: Dictionary) -> void:
	_ensure_light_manager()
	if _light_manager != null:
		_light_manager.push_lighting_override(token, data)


func pop_lighting_override(token: StringName) -> void:
	if _light_manager != null:
		_light_manager.pop_lighting_override(token)


func _ensure_light_manager() -> void:
	if _light_manager != null and is_instance_valid(_light_manager):
		return
	_light_manager = LightManager.new()
	_light_manager.name = "LightManager"
	add_child(_light_manager)
	_sync_light_manager_state()


func _apply_light_darkness(alpha: float) -> void:
	if _light_manager == null or not is_instance_valid(_light_manager):
		return
	_light_manager.set_darkness_alpha(alpha, night_darkness)


func _apply_menu_hidden(hidden: bool) -> void:
	if _light_manager == null or not is_instance_valid(_light_manager):
		return
	_light_manager.set_menu_hidden(hidden)


func _apply_rain_strength(strength: float) -> void:
	if _light_manager == null or not is_instance_valid(_light_manager):
		return
	_light_manager.set_rain_strength(strength)


func _try_connect_flow() -> void:
	if _flow_connected:
		return
	if Runtime == null or Runtime.game_flow == null:
		return
	var gf: Node = Runtime.game_flow
	if not gf.has_signal("base_state_changed"):
		return
	var cb := Callable(self, "_on_base_state_changed")
	if not gf.is_connected("base_state_changed", cb):
		gf.connect("base_state_changed", cb)
	_flow_connected = true
	var state_v: Variant = null
	if gf.has_method("get_base_state"):
		state_v = gf.call("get_base_state")
	else:
		state_v = gf.get("base_state")
	if state_v is StringName:
		_on_base_state_changed(&"", state_v)


func _sync_light_manager_state() -> void:
	if _light_manager == null or not is_instance_valid(_light_manager):
		return
	_apply_menu_hidden(_is_menu_state())
	if Runtime != null and Runtime.game_flow != null:
		var gf: Node = Runtime.game_flow
		var state_v: Variant = null
		if gf.has_method("get_base_state"):
			state_v = gf.call("get_base_state")
		else:
			state_v = gf.get("base_state")
		if state_v is StringName:
			var st: StringName = state_v
			var keep_night := st == GameStateNames.NIGHT
			if (
				st == GameStateNames.LOADING
				and _last_non_loading_base_state == GameStateNames.NIGHT
			):
				keep_night = true
			_light_manager.set_night_override_active(keep_night)
	if TimeManager != null:
		var m := int(TimeManager.get_minute_of_day())
		var a := _compute_darkness_alpha(m)
		_apply_light_darkness(a)


func _on_base_state_changed(_prev: StringName, next: StringName) -> void:
	if _light_manager == null or not is_instance_valid(_light_manager):
		return
	if next != GameStateNames.LOADING:
		_last_non_loading_base_state = next
	var keep_night := next == GameStateNames.NIGHT
	if next == GameStateNames.LOADING and _last_non_loading_base_state == GameStateNames.NIGHT:
		keep_night = true
	_light_manager.set_night_override_active(keep_night)


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
