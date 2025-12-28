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
func on_interact(_tool_data: ToolData, _cell: Vector2i = Vector2i.ZERO) -> bool:
	return false

func check_growth(is_wet: bool) -> void:
	if !is_wet:
		return

	if plant == null:
		return

	# days_grown is the number of watered days elapsed.
	# We delegate the math to SimulationRules so it matches offline simulation.
	var old_days := plant.days_grown
	var days_to_grow := 0
	if plant.data:
		days_to_grow = plant.data.days_to_grow

	var new_days := SimulationRules.predict_plant_growth(old_days, days_to_grow, is_wet)
	plant.days_grown = new_days

	# Update visuals based on the derived stage index.
	plant.update_visuals(plant.get_stage_idx())