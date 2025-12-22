class_name SeedBehavior
extends ToolBehavior

## The resource path or ID of the plant to grow.
## This should match a PlantData resource.
@export var plant_id: StringName

func try_use(_player, cell: Vector2i, _tool) -> bool:
	if plant_id == &"":
		return false

	var data := GridState.get_or_create_cell_data(cell)

	# If it's already soil, we just plant.
	if data.is_soil():
		return GridState.plant_seed(cell, plant_id)

	# ONLY auto-till if the terrain is already DIRT.
	# This enforces the Shovel -> Seeds (Hoe) flow.
	if data.terrain_id == GridCellData.TerrainType.DIRT:
		var tilled = GridState.set_soil(cell)
		if tilled:
			return GridState.plant_seed(cell, plant_id)

	return false

