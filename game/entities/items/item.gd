class_name Item
extends Area2D

const _MAGNET_MAX_SPEED := 320.0
const _MAGNET_ACCEL := 900.0
const _MAGNET_PICKUP_RADIUS := 10.0
const _MAGNET_Y_OFFSET := 8.0
const _MAGNET_SPEED_PER_PX := 12.0

@export var item_data: ItemData
@export var count: int = 1

var _target_body: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _is_ready_for_pickup: bool = false

@onready var activation_timer: Timer = $ActivationTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var save_component: SaveComponent = $SaveComponent


func _ready() -> void:
	_refresh_visuals()
	# Only run physics ticks while magnetizing.
	set_physics_process(false)
	if save_component != null and not save_component.state_applied.is_connected(_refresh_visuals):
		save_component.state_applied.connect(_refresh_visuals)

	body_entered.connect(_on_body_entered)

	# Small animation to "pop" out
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).from(Vector2.ZERO)
	tween.tween_callback(func(): z_index = 99)

	activation_timer.timeout.connect(_on_activation_timer_timeout)
	if not _is_ready_for_pickup:
		activation_timer.start()
	else:
		# If restored from save and already ready, check for overlapping players immediately.
		call_deferred("_on_activation_timer_timeout")


func _refresh_visuals() -> void:
	if sprite == null or not is_instance_valid(sprite) or item_data == null:
		return

	sprite.texture = item_data.icon


func _on_activation_timer_timeout() -> void:
	_is_ready_for_pickup = true

	# Check for players already in the area
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _physics_process(delta: float) -> void:
	if _target_body == null or not is_instance_valid(_target_body):
		_target_body = null
		_velocity = Vector2.ZERO
		monitoring = true
		set_physics_process(false)
		return

	var target_pos := _target_body.global_position
	target_pos.y -= _MAGNET_Y_OFFSET

	var to_target := target_pos - global_position
	var dist2: float = to_target.length_squared()
	var pickup_r2: float = _MAGNET_PICKUP_RADIUS * _MAGNET_PICKUP_RADIUS
	if dist2 <= pickup_r2:
		_collect_item()
		return

	var dist: float = sqrt(dist2)
	var desired_speed: float = min(_MAGNET_MAX_SPEED, dist * _MAGNET_SPEED_PER_PX)
	var desired_vel: Vector2 = to_target / max(0.001, dist) * desired_speed

	_velocity = _velocity.move_toward(desired_vel, _MAGNET_ACCEL * delta)
	global_position += _velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if not _is_ready_for_pickup:
		return

	if _target_body:
		return

	if body is Player:
		_target_body = body
		# Disable monitoring to prevent re-triggering and improve performance
		set_deferred("monitoring", false)
		set_physics_process(true)


func _collect_item() -> void:
	if item_data == null:
		push_warning("Item: Attempted to collect null item_data, freeing.")
		queue_free()
		return

	var player := _target_body as Player
	if not player:
		_target_body = null
		monitoring = true
		set_physics_process(false)
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
			set_physics_process(false)

			# Bounce away
			_is_ready_for_pickup = false
			var bounce_dir = Vector2.RIGHT.rotated(randf() * TAU)
			# Keep the bounce subtle; this usually means the inventory was full.
			var bounce_pos = global_position + bounce_dir * 10.0

			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "global_position", bounce_pos, 0.18)
			tween.tween_callback(func(): _is_ready_for_pickup = true)
