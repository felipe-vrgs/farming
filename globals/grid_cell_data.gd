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

## The active Soil entity at this cell (runtime only, not saved to disk).
## The active Plant entity at this cell (runtime only, not saved to disk).
var plant_node: Plant = null

var soil_terrains = {
	GridCellData.TerrainType.SOIL: true,
	GridCellData.TerrainType.SOIL_WET: true,
}

func has_plant() -> bool:
	return plant_node != null

func clear_soil() -> void:
	# Always reset the saved grid state back to dirt, even if there is no Soil node.
	# (E.g. shoveling a GRASS tile updates visuals via TileMap, but we must also update data.)
	if plant_node != null:
		plant_node.queue_free()
	plant_node = null
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
	var plant_data: PlantData = SoilGridState.get_plant_data(plant_id)
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
		if plant_node != null:
			plant_node.refresh()
