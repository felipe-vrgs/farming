@tool
class_name ObstacleData
extends Resource

## Data-driven obstacle definition for authoring non-tile obstacles as scenes.
## Intended for unique buildings/decorations that should still participate in:
## - physics collisions (StaticBody2D + CollisionShape2D)
## - grid blocking (GridOccupantComponent footprint registration)

var _obstacle_name: String = "Unnamed Obstacle"
@export var obstacle_name: String:
	get:
		return _obstacle_name
	set(v):
		if _obstacle_name == v:
			return
		_obstacle_name = v
		emit_changed()

@export_group("Visuals")
var _texture: Texture2D
@export var texture: Texture2D:
	get:
		return _texture
	set(v):
		if _texture == v:
			return
		_texture = v
		emit_changed()

var _centered: bool = true
@export var centered: bool:
	get:
		return _centered
	set(v):
		if _centered == v:
			return
		_centered = v
		emit_changed()

var _sprite_offset: Vector2 = Vector2.ZERO
@export var sprite_offset: Vector2:
	get:
		return _sprite_offset
	set(v):
		if _sprite_offset == v:
			return
		_sprite_offset = v
		emit_changed()

@export_group("Collision")
var _collision_size: Vector2 = Vector2(16, 16)
@export var collision_size: Vector2:
	get:
		return _collision_size
	set(v):
		if _collision_size == v:
			return
		_collision_size = v
		emit_changed()

var _collision_offset: Vector2 = Vector2.ZERO
@export var collision_offset: Vector2:
	get:
		return _collision_offset
	set(v):
		if _collision_offset == v:
			return
		_collision_offset = v
		emit_changed()

var _collision_layer: int = 2
@export var collision_layer: int:
	get:
		return _collision_layer
	set(v):
		if _collision_layer == v:
			return
		_collision_layer = v
		emit_changed()

var _collision_mask: int = 0
@export var collision_mask: int:
	get:
		return _collision_mask
	set(v):
		if _collision_mask == v:
			return
		_collision_mask = v
		emit_changed()

@export_group("Grid")
var _entity_type: Enums.EntityType = Enums.EntityType.BUILDING
@export var entity_type: Enums.EntityType:
	get:
		return _entity_type
	set(v):
		if _entity_type == v:
			return
		_entity_type = v
		emit_changed()
