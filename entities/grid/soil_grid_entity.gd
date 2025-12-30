class_name SoilGridEntity
extends Node

func on_interact(tool_data: ToolData, cell: Vector2i = Vector2i.ZERO) -> bool:
	# Shovel: Remove soil (revert to dirt)
	if tool_data.action_kind == Enums.ToolActionKind.SHOVEL:
		if not TileMapManager.has_valid_ground_neighbors(cell):
			return false
		return GridState.clear_cell(cell)

	# Water: Wet the soil
	if tool_data.action_kind == Enums.ToolActionKind.WATER:
		return GridState.set_wet(cell)

	# Seeds: Plant
	if tool_data.action_kind == Enums.ToolActionKind.HOE:
		var plant_id = tool_data.extra_data.get("plant_id", "")
		if String(plant_id).is_empty():
			return false
		return GridState.plant_seed(cell, plant_id)

	return false
