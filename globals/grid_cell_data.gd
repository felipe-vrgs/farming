class_name GridCellData
extends Resource

enum TerrainType {
	NONE = -1,
	GRASS = 0,
	DIRT = 2,
	SOIL = 4,
	SOIL_WET = 5
}

const TERRAIN_COLORS: Dictionary[TerrainType, Color] = {
	TerrainType.GRASS: Color("59c135"),
	TerrainType.DIRT: Color("9d5a37"),
	TerrainType.SOIL: Color("5d3621"),
	TerrainType.SOIL_WET: Color("3a2114")
}

const TERRAIN_COLORS_VARIANT: Dictionary[TerrainType, Color] = {
	TerrainType.GRASS: Color("a0dc5e"),
	TerrainType.DIRT: Color("f1be93"),
	TerrainType.SOIL: Color("8a6546"),
	TerrainType.SOIL_WET: Color("68452a")
}

@export var coords: Vector2i
@export var terrain_id: TerrainType = TerrainType.GRASS

var grid_entities: Dictionary[Enums.EntityType, GridEntity] = {}

var soil_terrains = {
	GridCellData.TerrainType.SOIL: true,
	GridCellData.TerrainType.SOIL_WET: true,
}

func has_plant() -> bool:
	return grid_entities.has(Enums.EntityType.PLANT)

func has_obstacle() -> bool:
	for entity in grid_entities.values():
		if entity.blocks_movement:
			return true
	return false

func get_entity_of_type(type: Enums.EntityType) -> GridEntity:
	return grid_entities.get(type)

func add_occupant(entity: GridEntity) -> void:
	grid_entities[entity.entity_type] = entity

func remove_occupant(entity: GridEntity) -> void:
	# Ensure we are removing the correct entity for that type
	if grid_entities.has(entity.entity_type) and grid_entities[entity.entity_type] == entity:
		grid_entities.erase(entity.entity_type)

func is_soil() -> bool:
	return soil_terrains.has(terrain_id)

func is_wet() -> bool:
	return terrain_id == GridCellData.TerrainType.SOIL_WET