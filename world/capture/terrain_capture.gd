class_name TerrainCapture
extends Object

static func capture_cells(grid_state: Node) -> Array[CellSnapshot]:
	var out: Array[CellSnapshot] = []
	if grid_state == null:
		return out

	# Prefer the new TerrainState API.
	var terrain_map: Dictionary = {}
	if TerrainState != null and TerrainState.has_method("get_persisted_terrain_map"):
		terrain_map = TerrainState.get_persisted_terrain_map()
	elif grid_state.has_method("debug_get_grid_data"):
		# Fallback for older builds: use debug view.
		var gd: Dictionary = grid_state.debug_get_grid_data()
		for cell in gd:
			var data := gd.get(cell) as GridCellData
			if data != null and bool(data.terrain_persist):
				terrain_map[cell] = int(data.terrain_id)

	for cell in terrain_map:
		var cs := CellSnapshot.new()
		cs.coords = cell
		cs.terrain_id = int(terrain_map[cell])
		out.append(cs)
	return out


