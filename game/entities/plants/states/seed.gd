extends PlantState


func enter() -> void:
	if plant:
		plant.update_visuals(0)  # Force seed frame (usually 0)
