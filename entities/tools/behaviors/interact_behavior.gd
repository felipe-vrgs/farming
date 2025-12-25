class_name InteractBehavior
extends ToolBehavior

func try_use(_player, cell: Vector2i, _tool) -> bool:
	var cell_data = GridState.get_or_create_cell_data(cell)

	# Try to find a plant at this cell
	if cell_data.has_plant():
		var plant = cell_data.get_entity_of_type(Enums.EntityType.PLANT)
		if plant is Plant:
			# If the plant has an interact method, call it
			if plant.has_method("interact"):
				plant.interact()
				return true

	# Future: Check for other interactables (chests, signs, etc)
	return false

