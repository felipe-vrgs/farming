class_name SoilGridEntity
extends InteractableComponent

func try_interact(ctx: InteractionContext) -> bool:
	if !ctx.is_tool():
		return false
	return _on_tool_interact(ctx)

func _on_tool_interact(ctx: InteractionContext) -> bool:
	var ok := false
	match ctx.tool_data.action_kind:
		Enums.ToolActionKind.SHOVEL:
			# Shovel: Remove soil (revert to dirt)
			if TileMapManager.has_valid_ground_neighbors(ctx.cell):
				ok = WorldGrid.clear_cell(ctx.cell)
		Enums.ToolActionKind.WATER:
			# Water: Wet the soil
			ok = WorldGrid.set_wet(ctx.cell)
		Enums.ToolActionKind.HOE:
			# Seeds: Plant
			var plant_id = ctx.tool_data.extra_data.get("plant_id", "")
			if not String(plant_id).is_empty():
				ok = WorldGrid.plant_seed(ctx.cell, plant_id)
		_:
			ok = false

	return ok
