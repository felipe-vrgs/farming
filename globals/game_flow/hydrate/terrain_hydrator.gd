class_name TerrainHydrator
extends Object


static func hydrate_cells_and_apply_tilemap(grid_state: Node, cells: Array[CellSnapshot]) -> void:
	if grid_state == null:
		return

	# New architecture: WorldGrid.terrain_state owns persisted terrain deltas.
	var cells_data: Dictionary = {}
	if WorldGrid.terrain_state != null:
		cells_data = WorldGrid.terrain_state.load_from_cell_snapshots(cells)

	# Apply to active tilemap visuals.
	WorldGrid.tile_map.restore_save_state(cells_data)
