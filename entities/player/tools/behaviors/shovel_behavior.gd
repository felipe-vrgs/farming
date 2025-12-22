class_name ShovelBehavior
extends ToolBehavior

func try_use(_player, cell: Vector2i, _tool) -> bool:
	var cell_data = SoilGridState.get_or_create_cell_data(cell)

	if not cell_data.has_soil() and cell_data.terrain_id != GridCellData.TerrainType.GRASS:
		return false

	# Extra safety: Don't shovel edges if the tileset doesn't support "Dirt at edge".
	if not cell_data.has_soil() and not SoilGridState.has_valid_neighbors(cell):
		return false

	# Clear soil entity (if any)
	SoilGridState.clear_cell(cell, cell_data)
	return true
