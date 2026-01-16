@tool
class_name LightEmitter2D
extends Node2D

enum LightCategory { WORLD, INTERIOR, NIGHT_ONLY }

var _category: LightCategory = LightCategory.WORLD
@export var category: LightCategory:
	get:
		return _category
	set(v):
		if _category == v:
			return
		_category = v
		_refresh_groups()

@export var base_energy: float = 1.0
@export var light_color: Color = Color(1, 1, 1, 1)
@export var enabled_by_default: bool = true
@export var auto_dim_with_darkness: bool = true
@export var light_texture: Texture2D = null
@export var texture_scale: float = 1.0
@export var preset: LightEmitterPreset:
	set(v):
		preset = v
		_apply_preset()

@onready var _light: PointLight2D = _get_or_create_light()

var category_name: StringName:
	get:
		match category:
			LightCategory.WORLD:
				return &"world"
			LightCategory.INTERIOR:
				return &"interior"
			LightCategory.NIGHT_ONLY:
				return &"night_only"
		return &""


func get_category_name() -> StringName:
	return category_name


func _enter_tree() -> void:
	_add_groups()
	if Engine.is_editor_hint():
		return
	_get_or_create_light().visible = false
	if DayNightManager != null and DayNightManager.has_method("register_light"):
		DayNightManager.register_light(self)


func _ready() -> void:
	_apply_preset()
	_apply_local_settings()
	if not Engine.is_editor_hint():
		_get_or_create_light().visible = false


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if DayNightManager != null and DayNightManager.has_method("unregister_light"):
		DayNightManager.unregister_light(self)


func apply_light_state(visible: bool, intensity: float) -> void:
	var l := _get_or_create_light()
	l.visible = visible
	l.energy = maxf(0.0, base_energy * maxf(0.0, intensity))


func _apply_local_settings() -> void:
	var l := _get_or_create_light()
	if base_energy <= 0.0:
		base_energy = maxf(0.001, l.energy)
	l.color = light_color
	if light_texture != null:
		l.texture = light_texture
	if texture_scale > 0.0:
		l.texture_scale = texture_scale
	if Engine.is_editor_hint():
		l.visible = enabled_by_default


func _get_or_create_light() -> PointLight2D:
	if _light != null and is_instance_valid(_light):
		return _light
	var existing := get_node_or_null(NodePath("PointLight2D"))
	if existing is PointLight2D:
		_light = existing as PointLight2D
		return _light
	var l := PointLight2D.new()
	l.name = "PointLight2D"
	add_child(l)
	l.visible = Engine.is_editor_hint()
	_light = l
	return _light


func _add_groups() -> void:
	add_to_group(Groups.LIGHT_EMITTERS)
	match category:
		LightCategory.WORLD:
			add_to_group(Groups.LIGHTS_WORLD)
		LightCategory.INTERIOR:
			add_to_group(Groups.LIGHTS_INTERIOR)
		LightCategory.NIGHT_ONLY:
			add_to_group(Groups.LIGHTS_NIGHT_ONLY)


func _refresh_groups() -> void:
	if not is_inside_tree():
		return
	remove_from_group(Groups.LIGHTS_WORLD)
	remove_from_group(Groups.LIGHTS_INTERIOR)
	remove_from_group(Groups.LIGHTS_NIGHT_ONLY)
	_add_groups()


func _apply_preset() -> void:
	if preset == null or not is_instance_valid(preset):
		return
	category = preset.category
	base_energy = preset.base_energy
	light_color = preset.light_color
	enabled_by_default = preset.enabled_by_default
	auto_dim_with_darkness = preset.auto_dim_with_darkness
	if preset.light_texture != null:
		light_texture = preset.light_texture
	if preset.texture_scale > 0.0:
		texture_scale = preset.texture_scale
	if is_inside_tree():
		_apply_local_settings()
