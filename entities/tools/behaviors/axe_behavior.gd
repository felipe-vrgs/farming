class_name AxeBehavior
extends ToolBehavior

func try_use(_player, cell: Vector2i, _tool) -> bool:
	var cell_data = SoilGridState.get_or_create_cell_data(cell)

	if cell_data.has_obstacle() and cell_data.obstacle_node.has_method("hit"):
		cell_data.obstacle_node.hit()
		return true

	return false
