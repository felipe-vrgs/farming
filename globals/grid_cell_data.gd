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
var soil_node: Node = null

func has_soil() -> bool:
	return soil_node != null

func clear_soil() -> void:
	if soil_node != null:
		soil_node.queue_free()
		is_wet = false
		terrain_id = GridCellData.TerrainType.DIRT
		soil_node = null
