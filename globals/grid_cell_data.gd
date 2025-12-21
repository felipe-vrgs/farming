class_name GridCellData
extends Resource

enum TerrainType {
	GRASS = 0,
	DIRT = 2,
	SOIL = 5,
	SOIL_WET = 6
}

@export var coords: Vector2i
@export var terrain_id: TerrainType = TerrainType.GRASS
@export var is_wet: bool = false
@export var plant_id: StringName = &""
@export var days_grown: int = 0
@export var growth_stage: int = 0

