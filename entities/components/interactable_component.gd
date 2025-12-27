class_name InteractableComponent
extends Node2D

## Virtual method called when a tool interacts with this entity.
func on_interact(_tool_data: ToolData, _cell: Vector2i = Vector2i.ZERO) -> bool:
	return false
