class_name AxeBehavior
extends ToolBehavior

func try_use(_player, cell: Vector2i, tool_data) -> bool:
	var entity = GridState.get_entity_at(cell, GridEntity.EntityType.TREE)

	if entity != null:
		entity.on_interact(tool_data)
		return true

	return false
