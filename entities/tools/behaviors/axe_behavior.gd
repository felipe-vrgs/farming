class_name AxeBehavior
extends ToolBehavior

func try_use(_player, cell: Vector2i, _tool) -> bool:
	print("Axe used on cell: ", cell)
	# Future: Check for trees/stumps and chop them
	return true

