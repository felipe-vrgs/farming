class_name PlantInteractable
extends InteractableComponent

func try_interact(ctx: InteractionContext) -> bool:
	if !ctx.is_tool():
		return false

	var plant := get_parent() as Plant
	if plant == null or plant.state_machine == null:
		return false
	if plant.state_machine.current_state is PlantState:
		return (plant.state_machine.current_state as PlantState).on_interact(ctx.tool_data, ctx.cell)
	return false

