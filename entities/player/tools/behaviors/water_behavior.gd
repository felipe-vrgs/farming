class_name WaterBehavior
extends ToolBehavior

func try_use(_player, cell: Vector2i, _tool) -> bool:
	var cell_data = SoilGridState.get_or_create_cell_data(cell)

	if not cell_data.is_wet and cell_data.has_soil():
		cell_data.soil_node.water()
		cell_data.is_wet = true
		SoilGridState.set_cell_data(cell, cell_data)
		return true

	return false
