class_name SimulationRules
extends Object

## Centralized game logic for world simulation (growth, decay, etc).
## Used by both runtime entities (GridState, Plant) and offline processors (GameManager).

## Returns the new terrain type for a cell after a day passes.
static func predict_soil_decay(current_terrain: int) -> int:
	if current_terrain == GridCellData.TerrainType.SOIL_WET:
		return GridCellData.TerrainType.SOIL
	# Could add logic for SOIL -> DIRT decay here later.
	return current_terrain

## Returns the new `days_grown` value for a plant.
static func predict_plant_growth(current_days: int, days_to_grow: int, is_wet: bool) -> int:
	if not is_wet:
		return current_days

	var next := current_days + 1
	if days_to_grow > 0:
		return mini(next, days_to_grow)
	return next

