class_name SoilInteractable
extends InteractableComponent


func try_interact(ctx: InteractionContext) -> bool:
	if !ctx.is_tool():
		return false
	return _on_tool_interact(ctx)


func _on_tool_interact(ctx: InteractionContext) -> bool:
	var ok := false
	match ctx.tool_data.action_kind:
		Enums.ToolActionKind.SHOVEL:
			# Shovel: Revert to dirt.
			if WorldGrid.tile_map.has_valid_ground_neighbors(ctx.cell):
				ok = WorldGrid.clear_cell(ctx.cell)
		Enums.ToolActionKind.WATER:
			# Water: Wet the soil
			ok = WorldGrid.set_wet(ctx.cell)
		Enums.ToolActionKind.HOE:
			# Hoe: Grass -> Dirt (if needed) -> Soil overlay.
			if WorldGrid.tile_map.has_valid_ground_neighbors(ctx.cell):
				var t := (
					WorldGrid.terrain_state.get_terrain_at(ctx.cell)
					if WorldGrid.terrain_state != null
					else GridCellData.TerrainType.NONE
				)
				if t == GridCellData.TerrainType.GRASS:
					# Convert the ground first so soil edges can reveal dirt underlay.
					if not WorldGrid.clear_cell(ctx.cell):
						return false
				ok = WorldGrid.set_soil(ctx.cell)
		_:
			ok = false

	return ok
