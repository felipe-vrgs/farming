class_name ToolBehavior
extends Resource

## Execute this tool action at the given grid cell.
## Return true only if the action actually changed the world / succeeded.
func try_use(_player, _cell: Vector2i, _tool) -> bool:
	return false


