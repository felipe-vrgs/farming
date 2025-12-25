class_name PlantState
extends State

var plant: Plant

func bind_parent(new_parent: Node) -> void:
	super.bind_parent(new_parent)
	if new_parent is Plant:
		plant = new_parent

# Plant states might need to react to day updates
func on_day_passed(_is_wet: bool) -> StringName:
	return PlantStateNames.NONE

# Plant states might need to react to tools
func on_interact() -> void:
	pass

func check_growth(is_wet: bool) -> void:
	if !is_wet:
		return

	if plant == null:
		return

	# days_grown is the number of watered days elapsed.
	plant.days_grown += 1

	# Cap growth so it doesn't overflow indefinitely.
	if plant.data and plant.data.days_to_grow > 0:
		plant.days_grown = mini(plant.days_grown, plant.data.days_to_grow)

	# Update visuals based on the derived stage index (do NOT overwrite days_grown).
	plant.update_visuals(plant.get_stage_idx())