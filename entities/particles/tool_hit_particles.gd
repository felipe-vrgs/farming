class_name ToolHitParticles
extends GPUParticles2D


const SHADER: Shader = preload("res://entities/particles/shaders/luma.gdshader")
const SHADER_ADD: Shader = preload("res://entities/particles/shaders/luma_add.gdshader")

@export var default_vfx: ToolHitVfxConfig
@export var vfx_z_index: int = 100

func _ready() -> void:
	# Lives under Player, but we position it in world-space.
	top_level = true
	z_as_relative = false
	z_index = vfx_z_index
	one_shot = true
	emitting = false

	if has_signal("finished"):
		finished.connect(_on_finished)

func play_at(world_pos: Vector2, vfx: ToolHitVfxConfig) -> void:
	var cfg := vfx if vfx != null else default_vfx
	if cfg == null:
		return

	global_position = world_pos
	z_index = vfx_z_index

	_apply_cfg_to_node(cfg, true)

	# Important: start emitting deferred so callers can set position first.
	emitting = false
	restart()
	call_deferred("_start_emit")

func _start_emit() -> void:
	emitting = true

func _on_finished() -> void:
	emitting = false

func _apply_cfg_to_node(cfg: ToolHitVfxConfig, duplicate_material: bool) -> void:
	if cfg == null:
		return

	texture = cfg.texture
	process_material = (
		cfg.process_material.duplicate(true)
		if (duplicate_material and cfg.process_material != null)
		else cfg.process_material
	)
	amount = cfg.amount
	lifetime = cfg.lifetime
	explosiveness = cfg.explosiveness
	speed_scale = cfg.speed_scale

	var sm := ShaderMaterial.new()
	sm.shader = SHADER_ADD if cfg.blend_additive else SHADER
	sm.set_shader_parameter("use_luminance_as_alpha", cfg.use_luminance_as_alpha)
	sm.set_shader_parameter("alpha_mult", cfg.alpha_mult)
	sm.set_shader_parameter("tint", cfg.tint)
	sm.set_shader_parameter("hard_alpha", cfg.hard_alpha)
	sm.set_shader_parameter("alpha_cutoff", cfg.alpha_cutoff)
	sm.set_shader_parameter("use_texture_rgb", cfg.use_texture_rgb)
	sm.set_shader_parameter("pixel_snap_uv", cfg.pixel_snap_uv)
	sm.set_shader_parameter("alpha_gamma", cfg.alpha_gamma)
	sm.set_shader_parameter("dither_alpha", cfg.dither_alpha)
	sm.set_shader_parameter("dither_strength", cfg.dither_strength)
	sm.set_shader_parameter("dither_scale", cfg.dither_scale)
	material = sm


