class_name WaterBehavior
extends ToolBehavior

func try_use(_player, cell: Vector2i, _tool) -> bool:
	return GridState.set_wet(cell)
