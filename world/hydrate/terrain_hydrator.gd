class_name TerrainHydrator
extends Object

static func hydrate_cells_and_apply_tilemap(grid_state: Node, cells: Array[CellSnapshot]) -> void:
	if grid_state == null:
		return

	# New architecture: TerrainState owns persisted terrain deltas.
	var cells_data: Dictionary = {}
	if TerrainState != null and TerrainState.has_method("load_from_cell_snapshots"):
		cells_data = TerrainState.load_from_cell_snapshots(cells)

	# Apply to active tilemap visuals.
	TileMapManager.restore_save_state(cells_data)
