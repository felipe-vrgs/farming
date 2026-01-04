class_name CellOccupancyData
extends Resource

## Runtime-only occupancy for a grid cell.
## This must NEVER be persisted; it is rebuilt from entities/components each load.

static var _obstacle_types := {
	Enums.EntityType.TREE: true,
	Enums.EntityType.ROCK: true,
	Enums.EntityType.BUILDING: true,
	Enums.EntityType.NPC: true,
}

@export var coords: Vector2i = Vector2i.ZERO

var entities: Dictionary[Enums.EntityType, Node] = {}
var obstacles: Dictionary[Enums.EntityType, bool] = {}


func has_obstacle() -> bool:
	return not obstacles.is_empty()


func get_entity_of_type(type: Enums.EntityType) -> Node:
	return entities.get(type)


func has_entity_type(type: Enums.EntityType) -> bool:
	return entities.has(type)


func add_entity(entity: Node, type: Enums.EntityType) -> void:
	entities[type] = entity
	if _obstacle_types.has(type):
		obstacles[type] = true


func remove_entity(entity: Node, type: Enums.EntityType) -> void:
	if entities.has(type) and entities[type] == entity:
		entities.erase(type)
		obstacles.erase(type)
