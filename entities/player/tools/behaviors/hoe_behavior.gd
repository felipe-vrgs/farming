class_name HoeBehavior
extends ToolBehavior

func try_use(_player, cell: Vector2i, _tool) -> bool:
	var cell_data = SoilGridState.get_or_create_cell_data(cell)

	if cell_data.terrain_id != GridCellData.TerrainType.DIRT:
		return false

	# If we already have soil here, nothing to do.
	if cell_data.has_soil():
		return false

	if SoilGridState.spawn_soil(cell) != null:
		cell_data.terrain_id = GridCellData.TerrainType.SOIL
		cell_data.is_wet = false
		SoilGridState.set_cell_data(cell, cell_data)
		return true
	return false
