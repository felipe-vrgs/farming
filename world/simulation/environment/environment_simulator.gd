class_name EnvironmentSimulator
extends RefCounted

## Unified driver for environment simulation (Soil Decay + Plant Growth).
## Works for both Online (SceneTree) and Offline (SaveFile) modes via adapters.

class WorldAdapter:
	## Returns all grid cells that might need simulation (e.g. wet soil, or containing plants).
	func get_cells_to_simulate() -> Array[Vector2i]:
		return []

	func get_terrain_at(_cell: Vector2i) -> int:
		return 0 # GridCellData.TerrainType.NONE

	## Returns plant data at the cell, or null if no plant.
	## Expected return: { "days_grown": int, "days_to_grow": int }
	func get_plant_data(_cell: Vector2i) -> Variant:
		return null

class SimulationResult:
	## cell -> new_terrain_type (int)
	var terrain_changes: Dictionary = {}
	## cell -> new_days_grown (int)
	var plant_changes: Dictionary = {}

static func simulate_day(world: WorldAdapter) -> SimulationResult:
	var res := SimulationResult.new()
	if world == null:
		return res

	var cells := world.get_cells_to_simulate()
	for cell in cells:
		var current_terrain := world.get_terrain_at(cell)
		var is_wet := current_terrain == GridCellData.TerrainType.SOIL_WET

		# 1. Plant Growth (based on pre-decay soil state)
		var plant_data = world.get_plant_data(cell)
		if plant_data != null and is_wet:
			var current_days: int = plant_data.get("days_grown", 0)
			var days_to_grow: int = plant_data.get("days_to_grow", 0)
			var new_days := predict_plant_growth(current_days, days_to_grow, is_wet)
			if new_days != current_days:
				res.plant_changes[cell] = new_days
		# 2. Soil Decay
		var new_terrain := predict_soil_decay(current_terrain)
		if new_terrain != current_terrain:
			res.terrain_changes[cell] = new_terrain

	return res

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


