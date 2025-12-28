class_name TerrainHydrator
extends Object

static func hydrate_cells_and_apply_tilemap(grid_state: Node, cells: Array[CellSnapshot]) -> void:
	if grid_state == null:
		return

	var cells_data := {}
	# Rebuild GridState data first
	for cs in cells:
		if cs == null:
			continue
		var cell: Vector2i = cs.coords
		var to_terrain: int = int(cs.terrain_id)
		var data := GridCellData.new()
		data.coords = cell
		data.terrain_id = to_terrain as GridCellData.TerrainType
		grid_state._grid_data[cell] = data

		cells_data[cell] = to_terrain

	# Apply to active tilemap visuals
	TileMapManager.restore_save_state(cells_data)
