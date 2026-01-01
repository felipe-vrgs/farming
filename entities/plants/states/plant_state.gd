class_name PlantState
extends State

var plant: Plant

func bind_parent(new_parent: Node) -> void:
	super.bind_parent(new_parent)
	if new_parent is Plant:
		plant = new_parent

# Plant states might need to react to tools
func on_interact(_tool_data: ToolData, _cell: Vector2i = Vector2i.ZERO) -> bool:
	return false
