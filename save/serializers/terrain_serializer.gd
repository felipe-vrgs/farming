class_name TerrainSerializer
extends Object

static func capture_cells(grid_state: Node) -> Array[CellSnapshot]:
	var out: Array[CellSnapshot] = []
	if grid_state == null:
		return out
	for cell in grid_state._grid_data:
		var data: GridCellData = grid_state._grid_data[cell]
		if data == null:
			continue
		var cs := CellSnapshot.new()
		cs.coords = data.coords
		cs.terrain_id = int(data.terrain_id)
		out.append(cs)
	return out

static func restore_cells_and_apply_tilemap(grid_state: Node, cells: Array[CellSnapshot]) -> void:
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

	# Direct restore to TileMapManager
	TileMapManager.restore_save_state(cells_data)
