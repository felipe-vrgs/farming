class_name HealthComponent
extends Node2D

## Signal emitted when health changes.
signal health_changed(current: float, max: float)
## Signal emitted when health reaches zero.
signal depleted

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

@export var max_health: float = 100.0

var _flash_timer: Timer

@onready var current_health: float = max_health

func _ready() -> void:
	_setup_flash()

func _setup_flash() -> void:
	if flash_node == null:
		return

	# Ensure the node has the hit flash shader
	if flash_node.material == null or not flash_node.material is ShaderMaterial:
		var sm := ShaderMaterial.new()
		sm.shader = HIT_FLASH_SHADER
		sm.set_shader_parameter("flash_color", flash_color)
		flash_node.material = sm

	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.wait_time = flash_duration
	_flash_timer.timeout.connect(_on_flash_timeout)
	add_child(_flash_timer)

func _on_flash_timeout() -> void:
	if flash_node and flash_node.material is ShaderMaterial:
		flash_node.material.set_shader_parameter("active", false)

## Apply damage to this component.
func take_damage(amount: float) -> void:
	if current_health <= 0:
		return

	current_health = max(0, current_health - amount)
	_trigger_flash()

	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		depleted.emit()

func _trigger_flash() -> void:
	if flash_node and flash_node.material is ShaderMaterial:
		flash_node.material.set_shader_parameter("active", true)
		_flash_timer.start()

## Reset health to max.
func heal_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

