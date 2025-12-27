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

func on_day_passed(_is_wet: bool) -> StringName:
	# Mature plants might wither if left too long (future feature)
	return PlantStateNames.NONE
