class_name ParticleConfig
extends Resource

@export_category("Visuals")
@export var texture: Texture2D
@export var shader: Shader
@export var amount: int = 8
@export var lifetime: float = 0.5
@export var one_shot: bool = true
@export var explosiveness: float = 0.8

@export_category("Shader Parameters")
@export var shader_params: Dictionary = {}

@export_category("Colors")
@export var color_a: Color = Color.WHITE
@export var color_b: Color = Color.WHITE

