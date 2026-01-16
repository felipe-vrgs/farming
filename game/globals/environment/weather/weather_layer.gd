class_name WeatherLayer
extends CanvasLayer

@export var rain_texture: Texture2D

@export var base_amount: int = 40
@export var base_gravity: float = 1000.0
@export var base_speed_min: float = 220.0
@export var base_speed_max: float = 330.0
@export var emission_margin: float = 384.0

@onready var _rain_particles: GPUParticles2D = $RainParticles
@onready var _overcast_rect: ColorRect = $Overcast
@onready var _lightning_rect: ColorRect = $LightningFlash

var _particle_material: ParticleProcessMaterial = null
var _lightning_tween: Tween = null


func _ready() -> void:
	follow_viewport_enabled = false
	follow_viewport_scale = 1.0
	_ensure_material()
	_apply_overcast()
	_lightning_rect.visible = false
	if rain_texture != null:
		_rain_particles.texture = rain_texture
	_rain_particles.local_coords = true
	_rain_particles.emitting = false
	_update_viewport_rect()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_update_viewport_rect):
		vp.size_changed.connect(_update_viewport_rect)
	set_process(true)


func _process(_delta: float) -> void:
	# Keep the rain coverage aligned with the active camera.
	_update_viewport_rect()


func set_rain_enabled(enabled: bool, intensity: float = 1.0) -> void:
	_rain_particles.emitting = enabled
	_set_rain_intensity(intensity)


func set_wind(direction: Vector2, strength: float) -> void:
	_ensure_material()
	var dir := direction
	if dir.length() < 0.01:
		dir = Vector2.ZERO
	var s := clampf(strength, 0.0, 1.0)
	var gravity_x := dir.x * s * 350.0
	_particle_material.gravity = Vector3(gravity_x, base_gravity, 0.0)
	_particle_material.direction = Vector3(clampf(dir.x, -1.0, 1.0), 1.0, 0.0)


func flash_lightning(strength: float = 1.0) -> void:
	var a := clampf(strength, 0.0, 1.0)
	if a <= 0.0:
		return
	if _lightning_tween != null and is_instance_valid(_lightning_tween):
		_lightning_tween.kill()
	_lightning_rect.visible = true
	_lightning_rect.color = Color(1, 1, 1, a)
	_lightning_tween = create_tween()
	_lightning_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lightning_tween.tween_property(_lightning_rect, "color:a", 0.85 * a, 0.05)
	_lightning_tween.tween_property(_lightning_rect, "color:a", 0.0, 0.18)
	_lightning_tween.tween_interval(0.06)
	_lightning_tween.tween_property(_lightning_rect, "color:a", 0.55 * a, 0.04)
	_lightning_tween.tween_property(_lightning_rect, "color:a", 0.0, 0.2)
	_lightning_tween.tween_callback(func() -> void: _lightning_rect.visible = false)


func _set_rain_intensity(intensity: float) -> void:
	var t := clampf(intensity, 0.0, 1.0)
	if t <= 0.0:
		_rain_particles.amount = 1
		return
	var min_amount := maxi(1, int(round(base_amount * 0.2)))
	var target_amount := int(round(base_amount * t))
	_rain_particles.amount = maxi(min_amount, target_amount)


func _apply_overcast() -> void:
	# Disabled: square overlay is too visible for now.
	_overcast_rect.visible = false


func _ensure_material() -> void:
	if _rain_particles == null:
		return
	if _rain_particles.process_material is ParticleProcessMaterial:
		_particle_material = _rain_particles.process_material as ParticleProcessMaterial
		return
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_material.direction = Vector3(0, 1, 0)
	_particle_material.spread = 18.0
	_particle_material.gravity = Vector3(0, base_gravity, 0)
	_particle_material.initial_velocity_min = base_speed_min
	_particle_material.initial_velocity_max = base_speed_max
	_particle_material.scale_min = 0.35
	_particle_material.scale_max = 0.7
	_rain_particles.process_material = _particle_material


func _update_viewport_rect() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var size := vp.get_visible_rect().size
	var half := size * 0.5
	_rain_particles.position = half
	if _particle_material != null:
		_particle_material.emission_box_extents = Vector3(
			half.x + emission_margin, half.y + emission_margin, 1.0
		)
	_rain_particles.visibility_rect = Rect2(
		Vector2(-half.x - emission_margin, -half.y - emission_margin),
		Vector2(size.x + emission_margin * 2.0, size.y + emission_margin * 2.0)
	)
	# Force fullscreen flash to track the camera viewport.
	_lightning_rect.position = Vector2.ZERO
	_lightning_rect.size = size
