class_name GridCellData
extends Resource

enum TerrainType {
	NONE = -1,
	GRASS = 0,
	STONE = 1,
	DIRT = 2,
	SOIL = 4,
	SOIL_WET = 5
}

const TERRAIN_COLORS: Dictionary[TerrainType, Color] = {
	TerrainType.GRASS: Color("59c135"),
	TerrainType.STONE: Color("808080"),
	TerrainType.DIRT: Color("9d5a37"),
	TerrainType.SOIL: Color("5d3621"),
	TerrainType.SOIL_WET: Color("3a2114")
}

const TERRAIN_COLORS_VARIANT: Dictionary[TerrainType, Color] = {
	TerrainType.GRASS: Color("a0dc5e"),
	TerrainType.STONE: Color("c0c0c0"),
	TerrainType.DIRT: Color("f1be93"),
	TerrainType.SOIL: Color("8a6546"),
	TerrainType.SOIL_WET: Color("68452a")
}

@export var coords: Vector2i
@export var terrain_id: TerrainType = TerrainType.GRASS

# If true, this cell's terrain state should be persisted (delta from the authored tilemap).
var terrain_persist: bool = false
var entities: Dictionary[Enums.EntityType, Node] = {}
var obstacles: Dictionary[Enums.EntityType, bool] = {}

var soil_terrains = {
	GridCellData.TerrainType.SOIL: true,
	GridCellData.TerrainType.SOIL_WET: true,
}

var obstacles_types = {
	Enums.EntityType.TREE: true,
	Enums.EntityType.ROCK: true,
	Enums.EntityType.BUILDING: true,
}

func has_plant() -> bool:
	return entities.has(Enums.EntityType.PLANT)

func has_obstacle() -> bool:
	return not obstacles.is_empty()

func get_entity_of_type(type: Enums.EntityType) -> Node:
	return entities.get(type)

func add_entity(entity: Node, type: Enums.EntityType) -> void:
	entities[type] = entity
	if obstacles_types.has(type):
		obstacles[type] = true

func remove_entity(entity: Node, type: Enums.EntityType) -> void:
	# Ensure we are removing the correct entity for that type
	if entities.has(type) and entities[type] == entity:
		entities.erase(type)
		obstacles.erase(type)

func is_soil() -> bool:
	return soil_terrains.has(terrain_id)

func is_wet() -> bool:
	return terrain_id == GridCellData.TerrainType.SOIL_WET

func is_grass() -> bool:
	return terrain_id == GridCellData.TerrainType.GRASS


