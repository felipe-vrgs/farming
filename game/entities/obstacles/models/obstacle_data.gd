@tool
class_name ObstacleData
extends Resource

## Data-driven obstacle definition for authoring non-tile obstacles as scenes.
## Intended for unique buildings/decorations that should still participate in:
## - physics collisions (StaticBody2D + CollisionShape2D)
## - grid blocking (GridOccupantComponent footprint registration)

@export var obstacle_name: String = "Unnamed Obstacle"

@export_group("Visuals")
@export var texture: Texture2D
@export var centered: bool = true
@export var sprite_offset: Vector2 = Vector2.ZERO

@export_group("Collision")
@export var collision_size: Vector2 = Vector2(16, 16)
@export var collision_offset: Vector2 = Vector2.ZERO
@export var collision_layer: int = 2
@export var collision_mask: int = 0

@export_group("Grid")
@export var entity_type: Enums.EntityType = Enums.EntityType.BUILDING
