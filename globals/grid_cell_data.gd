class_name GridCellData
extends Resource

enum TerrainType {
	NONE = -1,
	GRASS = 0,
	DIRT = 2,
	SOIL = 4,
	SOIL_WET = 5
}

@export var coords: Vector2i
@export var terrain_id: TerrainType = TerrainType.GRASS
@export var is_wet: bool = false
@export var plant_id: StringName = &""
@export var days_grown: int = 0
@export var growth_stage: int = 0

var grid_entities: Dictionary[GridEntity.EntityType, GridEntity] = {}

var soil_terrains = {
	GridCellData.TerrainType.SOIL: true,
	GridCellData.TerrainType.SOIL_WET: true,
}

func has_plant() -> bool:
	return grid_entities.has(GridEntity.EntityType.PLANT)

func has_obstacle() -> bool:
	for entity in grid_entities.values():
		if entity.blocks_movement:
			return true
	return false

func get_entity_of_type(type: GridEntity.EntityType) -> GridEntity:
	return grid_entities.get(type)

func add_occupant(entity: GridEntity) -> void:
	grid_entities[entity.entity_type] = entity

func remove_occupant(entity: GridEntity) -> void:
	# Ensure we are removing the correct entity for that type
	if grid_entities.has(entity.entity_type) and grid_entities[entity.entity_type] == entity:
		grid_entities.erase(entity.entity_type)

func clear_soil() -> void:
	var plant = get_entity_of_type(GridEntity.EntityType.PLANT)
	if plant != null:
		if is_instance_valid(plant):
			plant.queue_free()
		grid_entities.erase(GridEntity.EntityType.PLANT)

	is_wet = false
	terrain_id = GridCellData.TerrainType.DIRT
	plant_id = &""
	days_grown = 0
	growth_stage = 0

func is_soil() -> bool:
	return soil_terrains.has(terrain_id)

func advance_day() -> void:
	var was_wet = is_wet
	if is_wet:
		terrain_id = GridCellData.TerrainType.SOIL
		is_wet = false
	if String(plant_id).is_empty():
		return
	var plant_data: PlantData = GridState.get_plant_data(plant_id)
	if plant_data == null:
		return
	if was_wet:
		days_grown += 1
		if plant_data.days_to_grow > 0:
			var max_stage: int = plant_data.stage_count - 1
			growth_stage = clampi(
				floori(float(days_grown) / plant_data.days_to_grow * max_stage),
				0,
				max_stage
			)
		# Update the visual representation
		var plant = get_entity_of_type(GridEntity.EntityType.PLANT) as Plant
		if plant != null:
			plant.refresh()
