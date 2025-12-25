extends PlantState

func enter() -> void:
	if plant:
		# Ensure we show the last frame
		plant.update_visuals(plant.data.stage_count - 1)

func on_interact() -> void:
	print("Harvesting plant at ", plant.grid_pos)

	# Remove from grid data
	plant.destroy()

func on_day_passed(_is_wet: bool) -> StringName:
	# Mature plants might wither if left too long (future feature)
	return PlantStateNames.NONE
