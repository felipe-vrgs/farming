extends PlantState

func enter() -> void:
	if plant:
		# Ensure we show the last frame
		plant.update_visuals(plant.data.stage_count - 1)

func on_interact(tool_data: ToolData, _cell: Vector2i = Vector2i.ZERO) -> bool:
	if tool_data.action_kind == Enums.ToolActionKind.HARVEST:
		queue_free()
		return true

	return false
