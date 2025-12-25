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

	# Reset grid model first.
	grid_state._grid_data.clear()

	# Restore terrain by emitting terrain_changed against current TileMap state.
	# This keeps TileMapManager as the single writer of tile layers.
	var terrain_groups := {}
	for cs in cells:
		if cs == null:
			continue
		var cell: Vector2i = cs.coords
		var to_terrain: int = int(cs.terrain_id)
		var from_terrain: int = int(TileMapManager.get_terrain_at(cell))

		# Update authoritative model.
		var data := GridCellData.new()
		data.coords = cell
		data.terrain_id = to_terrain as GridCellData.TerrainType
		grid_state._grid_data[cell] = data

		if from_terrain == to_terrain:
			continue

		var key := (int(from_terrain) << 16) | (int(to_terrain) & 0xFFFF)
		if not terrain_groups.has(key):
			terrain_groups[key] = {
				"from": from_terrain,
				"to": to_terrain,
				"cells": [] as Array[Vector2i]
			}
		(terrain_groups[key]["cells"] as Array[Vector2i]).append(cell)

	for key in terrain_groups:
		var g = terrain_groups[key]
		EventBus.terrain_changed.emit(g["cells"], g["from"], g["to"])


