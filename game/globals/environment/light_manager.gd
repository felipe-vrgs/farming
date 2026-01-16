class_name LightManager
extends Node

## Central policy for LightEmitter2D instances.
## Owned by DayNightManager to ensure the same darkness curve drives tint + lights.

const _DEFAULT_NIGHT_DARKNESS := 0.9

var _lights: Array = []
var _darkness01: float = 0.0
var _night_override_active: bool = false
var _menu_hidden: bool = false
var _rain_strength: float = 0.0
var _rain_intensity_boost: float = 0.25
var _rain_min_intensity: float = 0.25

# Override stack (last pushed wins).
var _override_order: Array[StringName] = []
var _overrides: Dictionary = {}


func register_light(light: Node) -> void:
	if light == null or not is_instance_valid(light):
		return
	if _lights.has(light):
		_apply_to_light(light)
		return
	_lights.append(light)
	_apply_to_light(light)


func unregister_light(light: Node) -> void:
	if light == null:
		return
	_lights.erase(light)


func set_darkness_alpha(alpha: float, night_darkness: float = _DEFAULT_NIGHT_DARKNESS) -> void:
	var denom := maxf(night_darkness, 0.001)
	_darkness01 = clampf(alpha / denom, 0.0, 1.0)
	_apply_all()


func set_night_override_active(active: bool) -> void:
	if _night_override_active == active:
		return
	_night_override_active = active
	_apply_all()


func set_menu_hidden(hidden: bool) -> void:
	if _menu_hidden == hidden:
		return
	_menu_hidden = hidden
	_apply_all()


func set_rain_strength(strength: float, boost: float = -1.0, min_intensity: float = -1.0) -> void:
	_rain_strength = clampf(strength, 0.0, 1.0)
	if boost >= 0.0:
		_rain_intensity_boost = maxf(0.0, boost)
	if min_intensity >= 0.0:
		_rain_min_intensity = clampf(min_intensity, 0.0, 1.0)
	_apply_all()


func push_lighting_override(token: StringName, data: Dictionary) -> void:
	if String(token).is_empty():
		return
	_overrides[token] = data
	if _override_order.has(token):
		_override_order.erase(token)
	_override_order.append(token)
	_apply_all()


func pop_lighting_override(token: StringName) -> void:
	if String(token).is_empty():
		return
	_overrides.erase(token)
	_override_order.erase(token)
	_apply_all()


func _apply_all() -> void:
	for light in _lights:
		_apply_to_light(light)


func _get_override() -> Dictionary:
	if _override_order.is_empty():
		return {}
	var token: StringName = _override_order[_override_order.size() - 1]
	var data: Variant = _overrides.get(token, {})
	return data if data is Dictionary else {}


func _apply_to_light(light: Node) -> void:
	if light == null or not is_instance_valid(light):
		return
	if not light.has_method("apply_light_state"):
		return

	# Default policy (no overrides yet).
	var category: StringName = &""
	if light.has_method("get_category_name"):
		category = light.call("get_category_name")
	var enabled_default: bool = (
		bool(light.get("enabled_by_default")) if "enabled_by_default" in light else true
	)
	var auto_dim: bool = (
		bool(light.get("auto_dim_with_darkness")) if "auto_dim_with_darkness" in light else true
	)

	var visible := enabled_default
	var intensity := 1.0
	var rain_mul := 1.0 + (_rain_strength * _rain_intensity_boost)
	var rain_floor := _rain_strength * _rain_min_intensity

	if _menu_hidden:
		visible = false
	elif _night_override_active:
		visible = category == &"night_only"
		intensity = 1.0
	else:
		match category:
			&"world":
				var base := _darkness01 if auto_dim else 1.0
				intensity = maxf(base, rain_floor) * rain_mul
				visible = enabled_default and intensity > 0.001
			&"interior":
				var base_in := _darkness01 if auto_dim else 1.0
				intensity = maxf(base_in, rain_floor) * rain_mul
				visible = enabled_default and (intensity > 0.001 if auto_dim else true)
			&"night_only":
				visible = false
				intensity = 0.0
			_:
				visible = enabled_default
				intensity = 1.0

	# Apply overrides (last pushed wins).
	var o := _get_override()
	if not o.is_empty():
		if o.has("world_enabled") and category == &"world":
			visible = bool(o.world_enabled)
		if o.has("interior_enabled") and category == &"interior":
			visible = bool(o.interior_enabled)
		if o.has("night_only_enabled") and category == &"night_only":
			visible = bool(o.night_only_enabled)

		var mul := 1.0
		if category == &"world" and o.has("world_intensity_mul"):
			mul = float(o.world_intensity_mul)
		elif category == &"interior" and o.has("interior_intensity_mul"):
			mul = float(o.interior_intensity_mul)
		elif category == &"night_only" and o.has("night_intensity_mul"):
			mul = float(o.night_intensity_mul)
		intensity *= maxf(0.0, mul)

	light.call("apply_light_state", visible, intensity)
