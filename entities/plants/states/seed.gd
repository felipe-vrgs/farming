extends PlantState

func enter() -> void:
	if plant:
		plant.update_visuals(0) # Force seed frame (usually 0)

func on_day_passed(is_wet: bool) -> StringName:
	check_growth(is_wet)
	# Transition to Growing state once sprouted (stage > 0)
	if plant and plant.get_stage_idx() > 0:
		return PlantStateNames.GROWING
	return PlantStateNames.NONE
