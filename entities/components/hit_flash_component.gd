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

var _flash_timer: Timer

func _ready() -> void:
	_setup_flash()

func _setup_flash() -> void:
	if flash_node == null:
		return

	# Ensure the node has the hit flash shader (and not just any ShaderMaterial).
	var sm: ShaderMaterial = null
	if flash_node.material is ShaderMaterial:
		var existing := flash_node.material as ShaderMaterial
		if existing.shader == HIT_FLASH_SHADER:
			sm = existing
	if sm == null:
		sm = ShaderMaterial.new()
		sm.shader = HIT_FLASH_SHADER
		flash_node.material = sm

	# Keep shader params in sync and ensure we start from "not flashing".
	sm.set_shader_parameter("flash_color", flash_color)
	sm.set_shader_parameter("active", false)

	if _flash_timer == null:
		_flash_timer = Timer.new()
		_flash_timer.one_shot = true
		_flash_timer.timeout.connect(_on_flash_timeout)
		add_child(_flash_timer)
	_flash_timer.wait_time = flash_duration

func on_flash_requested() -> void:
	_trigger_flash()

func _trigger_flash() -> void:
	if flash_node == null:
		return
	if not is_inside_tree():
		return

	# If this component was created/configured at runtime, make sure we're fully set up.
	_setup_flash()

	if flash_node.material is ShaderMaterial:
		var sm := flash_node.material as ShaderMaterial
		sm.set_shader_parameter("flash_color", flash_color)
		sm.set_shader_parameter("active", true)

		if _flash_timer != null:
			_flash_timer.stop()
			_flash_timer.wait_time = flash_duration
			_flash_timer.start()

func _on_flash_timeout() -> void:
	if flash_node and flash_node.material is ShaderMaterial:
		flash_node.material.set_shader_parameter("active", false)

