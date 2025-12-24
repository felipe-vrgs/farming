class_name VFX
extends Node2D

var _is_active: bool = false
var _config: ParticleConfig

@onready var particles: GPUParticles2D = $GPUParticles2D


func _ready() -> void:
	# Ensure particles don't start emitting automatically
	particles.emitting = false
	particles.finished.connect(_on_finished)

func setup(config: ParticleConfig) -> void:
	_config = config

	# Configure Particle System
	particles.amount = config.amount
	particles.lifetime = config.lifetime
	particles.one_shot = config.one_shot
	particles.explosiveness = config.explosiveness

	# Texture
	if config.texture:
		particles.texture = config.texture

	# Shader / Material
	if config.shader:
		var mat = ShaderMaterial.new()
		mat.shader = config.shader

		# Set default params from config
		for key in config.shader_params:
			mat.set_shader_parameter(key, config.shader_params[key])

		# Set default colors
		mat.set_shader_parameter("color_a", config.color_a)
		mat.set_shader_parameter("color_b", config.color_b)

		particles.process_material = mat

func play(pos: Vector2, z_idx: int, colors_override: Array = []) -> void:
	global_position = pos
	z_index = z_idx
	visible = true
	_is_active = true

	# Apply dynamic color overrides if provided (for terrain awareness)
	if not colors_override.is_empty() and particles.process_material is ShaderMaterial:
		var mat = particles.process_material as ShaderMaterial
		if colors_override.size() >= 1:
			mat.set_shader_parameter("color_a", colors_override[0])
		if colors_override.size() >= 2:
			mat.set_shader_parameter("color_b", colors_override[1])
		else:
			mat.set_shader_parameter("color_b", colors_override[0])

	particles.restart()
	particles.emitting = true

func _on_finished() -> void:
	_is_active = false
	visible = false
	# We don't queue_free, we just hide and wait for reuse
