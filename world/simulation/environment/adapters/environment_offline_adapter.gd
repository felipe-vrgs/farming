class_name OfflineEnvironmentAdapter
extends EnvironmentSimulator.WorldAdapter

## Adapter that exposes a `LevelSave` as an EnvironmentSimulator.WorldAdapter.
## This keeps the simulator rules identical for offline and online modes.

var _ls: LevelSave

## Vector2i -> CellSnapshot
var _cells_map: Dictionary = {}
## Vector2i -> EntitySnapshot (plant)
var _plants_map: Dictionary = {}
## String (resource path) -> PlantData
var _plant_data_cache: Dictionary = {}

func _init(ls: LevelSave) -> void:
	_ls = ls
	if _ls == null:
		return

	# Index for O(1) lookup during simulation + apply.
	for cs in _ls.cells:
		if cs != null:
			_cells_map[cs.coords] = cs
	for es in _ls.entities:
		if es == null:
			continue
		if int(es.entity_type) != int(Enums.EntityType.PLANT):
			continue
		# Assume at most one plant per cell; keep the first if duplicates exist.
		if not _plants_map.has(es.grid_pos):
			_plants_map[es.grid_pos] = es

func get_cells_to_simulate() -> Array[Vector2i]:
	var cell_set := {}
	for k in _cells_map:
		cell_set[k] = true
	for k in _plants_map:
		cell_set[k] = true
	var out: Array[Vector2i] = []
	for k in cell_set:
		out.append(k)
	return out

func get_terrain_at(cell: Vector2i) -> int:
	var cs: CellSnapshot = _cells_map.get(cell)
	if cs != null:
		return int(cs.terrain_id)
	return int(GridCellData.TerrainType.NONE)

func get_plant_data(cell: Vector2i) -> Variant:
	var es: EntitySnapshot = _plants_map.get(cell)
	if es == null:
		return null

	var plant_path := String(es.state.get("data", ""))
	if plant_path.is_empty():
		return null

	var pd: PlantData = _plant_data_cache.get(plant_path)
	if pd == null:
		var res = load(plant_path)
		if res is PlantData:
			pd = res
			_plant_data_cache[plant_path] = pd
		else:
			return null

	return {
		"days_grown": int(es.state.get("days_grown", 0)),
		"days_to_grow": int(pd.days_to_grow),
	}

func apply_result(result: EnvironmentSimulator.SimulationResult) -> void:
	if _ls == null or result == null:
		return

	# 1) Terrain deltas: only mutate snapshots that already exist in the save.
	for cell in result.terrain_changes:
		var cs: CellSnapshot = _cells_map.get(cell)
		if cs != null:
			cs.terrain_id = int(result.terrain_changes[cell])

	# 2) Plants: update days_grown in-place on the plant snapshot state.
	for cell in result.plant_changes:
		var es: EntitySnapshot = _plants_map.get(cell)
		if es == null:
			continue
		if es.state == null:
			es.state = {}
		es.state["days_grown"] = int(result.plant_changes[cell])
