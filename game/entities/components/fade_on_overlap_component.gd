class_name FadeOnOverlapComponent
extends Area2D

## Detects player overlap and fades target sprites.
## Useful for trees/buildings hiding the player when they walk behind them.

## Sprites to fade when player overlaps.
@export var target_sprites: Array[CanvasItem] = []

## Alpha value when faded (0 to 1).
@export_range(0.0, 1.0) var faded_alpha: float = 0.4

## Duration of the fade transition in seconds.
@export var fade_duration: float = 0.2

var _original_modulates: Array[Color] = []
var _tween: Tween = null


func _ready() -> void:
	# Default collision setup: detect player layer.
	collision_layer = 0
	collision_mask = 3  # Layers 1 & 2 (Player is usually 1)
	monitorable = false
	monitoring = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Cache original colors
	for sprite in target_sprites:
		if sprite:
			_original_modulates.append(sprite.modulate)


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_fade_to(faded_alpha)


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		# Only restore if no other players are inside (multiplayer proofing)
		if not has_overlapping_bodies():
			_fade_to(1.0)
		else:
			# Check if any remaining body is a player
			var check_overlap := get_overlapping_bodies()
			var player_remains := false
			for b in check_overlap:
				if _is_player(b):
					player_remains = true
					break
			if not player_remains:
				_fade_to(1.0)


func _is_player(body: Node2D) -> bool:
	if body.is_in_group("player"):  # Use string literal as fallback
		return true
	# Also check via Groups global if available (pseudo-code check)
	# if Groups.PLAYER and body.is_in_group(Groups.PLAYER): return true
	return false


func _fade_to(target_alpha: float) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	for i in range(target_sprites.size()):
		var sprite = target_sprites[i]
		if sprite != null and is_instance_valid(sprite):
			# Determine target color: keep original RGB, change A
			var target_col = _original_modulates[i]
			target_col.a = target_alpha

			_tween.tween_property(sprite, "modulate", target_col, fade_duration)
