class_name HitFlashComponent
extends Node

const HIT_FLASH_SHADER = preload("res://entities/particles/shaders/hit_flash.gdshader")

## Node to flash when taking damage (usually a Sprite2D or AnimatedSprite2D).
@export var flash_node: CanvasItem:
	set(val):
		flash_node = val
		if is_inside_tree():
			_setup_flash()

## Color to flash.
@export var flash_color: Color = Color(1, 1, 1, 1)
## Duration of the flash in seconds.
@export var flash_duration: float = 0.1
## The HealthComponent to listen to.
@export var health_component: HealthComponent

var _flash_timer: Timer

func _ready() -> void:
	_setup_flash()
	if health_component:
		health_component.health_changed.connect(_on_health_changed)

func _setup_flash() -> void:
	if flash_node == null:
		return

	# Ensure the node has the hit flash shader
	if flash_node.material == null or not flash_node.material is ShaderMaterial:
		var sm := ShaderMaterial.new()
		sm.shader = HIT_FLASH_SHADER
		sm.set_shader_parameter("flash_color", flash_color)
		flash_node.material = sm

	if _flash_timer == null:
		_flash_timer = Timer.new()
		_flash_timer.one_shot = true
		_flash_timer.wait_time = flash_duration
		_flash_timer.timeout.connect(_on_flash_timeout)
		add_child(_flash_timer)

func _on_health_changed(_current: float, _max_health: float) -> void:
	_trigger_flash()

func _trigger_flash() -> void:
	if flash_node and flash_node.material is ShaderMaterial:
		flash_node.material.set_shader_parameter("active", true)
		if _flash_timer:
			_flash_timer.start()

func _on_flash_timeout() -> void:
	if flash_node and flash_node.material is ShaderMaterial:
		flash_node.material.set_shader_parameter("active", false)

