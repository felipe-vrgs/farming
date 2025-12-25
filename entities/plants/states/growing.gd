extends PlantState

func enter() -> void:
	if plant:
		# Update visuals to match current growth stage
		plant.update_visuals(plant.get_stage_idx())

func on_day_passed(is_wet: bool) -> StringName:
	if plant == null:
		return PlantStateNames.NONE

	check_growth(is_wet)

	# Check again if it reached maturity after growth
	if plant.data and plant.get_stage_idx() >= (plant.data.stage_count - 1):
		return PlantStateNames.MATURE

	return PlantStateNames.NONE
