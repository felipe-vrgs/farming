class_name OfflineSimulation
extends Object

## Computes one "day tick" for an unloaded level save (mutates `ls` in-place).
static func compute_offline_day_for_level_save(ls: LevelSave) -> void:
	if ls == null:
		return

	# 1) Identify wet cells and apply soil decay.
	var wet := {} # Vector2i -> true
	for cs in ls.cells:
		if cs == null:
			continue

		var old_t := int(cs.terrain_id)
		var new_t := SimulationRules.predict_soil_decay(old_t)

		if old_t == int(GridCellData.TerrainType.SOIL_WET):
			wet[cs.coords] = true

		if old_t != new_t:
			cs.terrain_id = new_t

	# 2) Grow plants that were wet.
	for es in ls.entities:
		if es == null:
			continue
		if int(es.entity_type) != int(Enums.EntityType.PLANT):
			continue

		# Check if plant was on wet soil
		if not wet.has(es.grid_pos):
			continue

		var plant_path := String(es.state.get("data", ""))
		if plant_path.is_empty():
			continue
		var res = load(plant_path)
		if not (res is PlantData):
			continue
		var pd := res as PlantData

		var current_days := int(es.state.get("days_grown", 0))
		var new_days := SimulationRules.predict_plant_growth(current_days, pd.days_to_grow, true)

		if current_days != new_days:
			es.state["days_grown"] = new_days


