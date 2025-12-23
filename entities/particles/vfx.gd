class_name VFX
extends Node2D

@onready var particles: GPUParticles2D = $GPUParticles2D

## Generic setup: Sets color and texture
func setup_visuals(color: Color, texture_override: Texture2D = null) -> void:
	particles.modulate = color
	if texture_override:
		particles.texture = texture_override

## Sets multiple colors for the shader to pick from
func setup_colors(colors: Array) -> void:
	if colors.size() == 0:
		return

	# Since 'instance uniform' is not supported for particle shaders,
	# we make the material unique for this instance.
	var mat = particles.process_material
	if mat is ShaderMaterial:
		particles.process_material = mat.duplicate()
		mat = particles.process_material

		if colors.size() >= 1:
			mat.set_shader_parameter("color_a", colors[0])
		if colors.size() >= 2:
			mat.set_shader_parameter("color_b", colors[1])
		else:
			mat.set_shader_parameter("color_b", colors[0])

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
