extends Node

## Facade over the grid subsystems.
## - `TerrainState`: persisted terrain deltas + render events + farm simulation
## - `OccupancyGrid`: runtime-only entity registration/queries
##
## Keep this thin so gameplay code doesn't need to know which subsystem to call.

func _ready() -> void:
	set_process(false)
	ensure_initialized()

func ensure_initialized() -> bool:
	if TileMapManager == null or not TileMapManager.ensure_initialized():
		return false
	if TerrainState == null or OccupancyGrid == null:
		return false
	return TerrainState.ensure_initialized() and OccupancyGrid.ensure_initialized()

func apply_day_started(day_index: int) -> void:
	if TerrainState != null:
		TerrainState.apply_day_started(day_index)

# region Terrain facade

func set_soil(cell: Vector2i) -> bool:
	return TerrainState != null and TerrainState.set_soil(cell)

func set_wet(cell: Vector2i) -> bool:
	return TerrainState != null and TerrainState.set_wet(cell)

func plant_seed(cell: Vector2i, plant_id: StringName) -> bool:
	return TerrainState != null and TerrainState.plant_seed(cell, plant_id)

func clear_cell(cell: Vector2i) -> bool:
	return TerrainState != null and TerrainState.clear_cell(cell)

# endregion

# region Occupancy facade

func register_entity(cell: Vector2i, entity: Node, type: Enums.EntityType) -> void:
	if OccupancyGrid != null:
		OccupancyGrid.register_entity(cell, entity, type)

func unregister_entity(cell: Vector2i, entity: Node, type: Enums.EntityType) -> void:
	if OccupancyGrid != null:
		OccupancyGrid.unregister_entity(cell, entity, type)

func get_entities_at(cell: Vector2i) -> Array[Node]:
	var entities: Array[Node] = []
	if OccupancyGrid != null:
		entities = OccupancyGrid.get_entities_at(cell)
	if TerrainState != null:
		var soil := TerrainState.get_soil_interactable()
		if soil != null:
			entities.append(soil)
	return entities

# endregion

# region Debug helpers

func debug_get_grid_data() -> Dictionary:
	# Returns a merged view (Vector2i -> GridCellData) for debug overlays only.
	if not OS.is_debug_build():
		return {}
	var out: Dictionary = {}

	var terrain_cells = TerrainState.debug_get_terrain_cells() if TerrainState != null else {}
	var occ_cells: Dictionary = OccupancyGrid.debug_get_cells() if OccupancyGrid != null else {}

	var all_cells := {}
	for c in terrain_cells:
		all_cells[c] = true
	for c in occ_cells:
		all_cells[c] = true

	for cell in all_cells:
		var gd := GridCellData.new()
		gd.coords = cell
		gd.terrain_id = GridCellData.TerrainType.NONE
		if TerrainState != null:
			gd.terrain_id = TerrainState.get_terrain_at(cell)

		var tdata = terrain_cells.get(cell)
		if tdata != null:
			gd.terrain_persist = bool(tdata.get("terrain_persist"))

		var odata = occ_cells.get(cell)
		if odata != null:
			gd.entities = odata.get("entities")
			gd.obstacles = odata.get("obstacles")

		out[cell] = gd

	return out

# endregion


