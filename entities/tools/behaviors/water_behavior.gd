class_name WaterBehavior
extends ToolBehavior

func try_use(_player, cell: Vector2i, _tool) -> bool:
	return SoilGridState.set_wet(cell, true)
