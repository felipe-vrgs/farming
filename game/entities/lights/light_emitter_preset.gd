class_name LightEmitterPreset
extends Resource

@export var category: LightEmitter2D.LightCategory = LightEmitter2D.LightCategory.WORLD
@export var base_energy: float = 1.0
@export var light_color: Color = Color(1, 1, 1, 1)
@export var enabled_by_default: bool = true
@export var auto_dim_with_darkness: bool = true
@export var light_texture: Texture2D = null
@export var texture_scale: float = 1.0
