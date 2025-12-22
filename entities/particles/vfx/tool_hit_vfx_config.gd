class_name ToolHitVfxConfig
extends Resource

@export var texture: Texture2D
@export var process_material: ParticleProcessMaterial

## If your particle textures are "white on black", keep this on so black becomes transparent.
@export var use_luminance_as_alpha: bool = true
@export var tint: Color = Color(1, 1, 1, 1)
@export var alpha_mult: float = 1.0
## Pixel-art look helpers (shader-driven).
@export var hard_alpha: bool = true
@export var alpha_cutoff: float = 0.35
@export var use_texture_rgb: bool = false
@export var pixel_snap_uv: bool = true
@export var alpha_gamma: float = 1.0
@export var dither_alpha: bool = false
@export var dither_strength: float = 0.18
@export var dither_scale: float = 1.0
@export var blend_additive: bool = false

@export var amount: int = 12
@export var lifetime: float = 0.35
@export var explosiveness: float = 1.0
@export var speed_scale: float = 1.0


