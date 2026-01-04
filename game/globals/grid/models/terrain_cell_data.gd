class_name TerrainCellData
extends Resource

## Runtime terrain state for a single cell.
## This is the ONLY persisted part of the grid (as deltas from the authored TileMap).

@export var coords: Vector2i = Vector2i.ZERO
@export var terrain_id: GridCellData.TerrainType = GridCellData.TerrainType.NONE

## If true, this cell's terrain state should be persisted (delta from the authored tilemap).
@export var terrain_persist: bool = false


func is_soil() -> bool:
	return (
		terrain_id == GridCellData.TerrainType.SOIL
		or terrain_id == GridCellData.TerrainType.SOIL_WET
	)


func is_wet() -> bool:
	return terrain_id == GridCellData.TerrainType.SOIL_WET


func is_grass() -> bool:
	return terrain_id == GridCellData.TerrainType.GRASS
