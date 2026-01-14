class_name FadeOnOverlapComponent
extends Area2D

## Detects player overlap and fades target sprites.
## Useful for trees/buildings hiding the player when they walk behind them.

## Sprites to fade when player overlaps.
@export var target_sprites: Array[NodePath] = []

## Alpha value when faded (0 to 1).
@export_range(0.0, 1.0) var faded_alpha: float = 0.4

## Duration of the fade transition in seconds.
@export var fade_duration: float = 0.2

var _original_modulates: Array[Color] = []
var _resolved_sprites: Array[CanvasItem] = []
var _tween: Tween = null


func _ready() -> void:
	# Default collision setup: detect player layer.
	if collision_layer == 0:
		# Use Terrain layer (2) so the player mask can see us.
		set_collision_layer_value(2, true)
	if collision_mask == 0:
		collision_mask = 3  # Layers 1 & 2 (Player is usually 1)
	monitorable = false
	monitoring = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Cache original colors (strip nulls to keep indices aligned).
	_resolve_targets()
	call_deferred("_sync_initial_overlap")


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_fade_to(faded_alpha)


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		# Only restore if no other players are inside (multiplayer proofing).
		if not _has_player_overlap():
			_fade_to(1.0)


func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player")


func _fade_to(target_alpha: float) -> void:
	if _resolved_sprites.is_empty():
		_resolve_targets()
	if _resolved_sprites.is_empty():
		return
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	for i in range(_resolved_sprites.size()):
		var sprite = _resolved_sprites[i]
		if sprite != null and is_instance_valid(sprite):
			# Determine target color: keep original RGB, change A
			var target_col = _original_modulates[i]
			target_col.a = target_alpha

			_tween.tween_property(sprite, "modulate", target_col, fade_duration)


func _sync_initial_overlap() -> void:
	# Handle cases where the player starts inside the area.
	if not monitoring:
		return
	if _has_player_overlap():
		_fade_to(faded_alpha)
	else:
		_fade_to(1.0)


func _has_player_overlap() -> bool:
	if not has_overlapping_bodies():
		return false
	for body in get_overlapping_bodies():
		if _is_player(body):
			return true
	return false


func _resolve_targets() -> void:
	_original_modulates.clear()
	_resolved_sprites.clear()

	for entry in target_sprites:
		var sprite: CanvasItem = null
		if entry != NodePath(""):
			sprite = get_node_or_null(entry)

		if sprite != null and is_instance_valid(sprite) and not _resolved_sprites.has(sprite):
			_resolved_sprites.append(sprite)
			_original_modulates.append(sprite.modulate)

	if _resolved_sprites.is_empty():
		# Fallback: auto-pick canvas children (useful when nodes are spawned at runtime).
		var p := get_parent()
		var visual := p.get_node_or_null(NodePath("Visual")) if p != null else null
		var container := visual if visual != null else p
		if container != null:
			for child in container.get_children():
				if child is CanvasItem and not _resolved_sprites.has(child):
					var ci := child as CanvasItem
					_resolved_sprites.append(ci)
					_original_modulates.append(ci.modulate)
