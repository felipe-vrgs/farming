class_name TerrainCapture
extends Object

static func capture_cells(grid_state: Node) -> Array[CellSnapshot]:
	var out: Array[CellSnapshot] = []
	if grid_state == null:
		return out
	for cell in grid_state._grid_data:
		var data: GridCellData = grid_state._grid_data[cell]
		if data == null:
			continue
		# Only persist terrain deltas; occupancy-only cells are not saved.
		if not data.terrain_persist:
			continue
		var cs := CellSnapshot.new()
		cs.coords = data.coords
		cs.terrain_id = int(data.terrain_id)
		out.append(cs)
	return out


