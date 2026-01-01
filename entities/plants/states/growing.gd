extends PlantState

func enter() -> void:
	if plant:
		# Update visuals to match current growth stage
		plant.update_visuals(plant.get_stage_idx())