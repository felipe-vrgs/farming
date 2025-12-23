class_name VFX
extends Node2D

@onready var particles: GPUParticles2D = $GPUParticles2D

## Generic setup: Sets color and texture
func setup_visuals(color: Color, texture_override: Texture2D = null) -> void:
	particles.modulate = color
	if texture_override:
		particles.texture = texture_override

## Advanced setup: Overrides the shader/process material logic
func setup_logic(shader: Shader, params: Dictionary = {}) -> void:
	if not shader:
		return

	var mat = ShaderMaterial.new()
	mat.shader = shader

	for key in params:
		mat.set_shader_parameter(key, params[key])

	particles.process_material = mat

## Play the effect
func play() -> void:
	particles.emitting = true
	var lifetime = particles.lifetime
	get_tree().create_timer(lifetime + 0.1).timeout.connect(queue_free)
