class_name WorldItem
extends Area2D

@export var item_data: ItemData
@export var count: int = 1

var _target_body: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _is_ready_for_pickup: bool = false

@onready var activation_timer: Timer = $ActivationTimer
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if item_data:
		sprite.texture = item_data.icon

	body_entered.connect(_on_body_entered)

	# Small animation to "pop" out
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).from(Vector2.ZERO)

	activation_timer.timeout.connect(_on_activation_timer_timeout)
	activation_timer.start()

func _on_activation_timer_timeout() -> void:
	_is_ready_for_pickup = true

	# Check for players already in the area
	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _physics_process(delta: float) -> void:
	if _target_body:
		var target_pos = _target_body.global_position
		# Offset slightly to aim for center/chest
		target_pos.y -= 8.0

		var direction = global_position.direction_to(target_pos)
		var distance = global_position.distance_to(target_pos)
		var speed = 300.0 # Max speed
		var acceleration = 800.0

		_velocity = _velocity.move_toward(direction * speed, acceleration * delta)
		global_position += _velocity * delta

		# If close enough, collect
		if distance < 10.0:
			_collect_item()

func _on_body_entered(body: Node2D) -> void:
	if not _is_ready_for_pickup:
		return

	if _target_body:
		return

	if body is Player:
		_target_body = body
		# Disable monitoring to prevent re-triggering and improve performance
		set_deferred("monitoring", false)

func _collect_item() -> void:
	var player := _target_body as Player
	if not player:
		_target_body = null
		monitoring = true
		return

	if player.inventory:
		var remaining = player.inventory.add_item(item_data, count)
		if remaining == 0:
			# TODO: Play pickup sound/VFX
			queue_free()
		else:
			count = remaining
			_target_body = null
			monitoring = true

			# Bounce away
			_is_ready_for_pickup = false
			var bounce_dir = Vector2.RIGHT.rotated(randf() * TAU)
			var bounce_pos = global_position + bounce_dir * 32.0

			var tween = create_tween()
			tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "global_position", bounce_pos, 0.4)
			tween.tween_callback(func(): _is_ready_for_pickup = true)
