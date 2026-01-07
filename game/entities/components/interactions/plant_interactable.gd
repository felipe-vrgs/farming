class_name PlantInteractable
extends InteractableComponent

const _SFX_HARVEST := preload("res://assets/sounds/items/harvest_pickup.mp3")


static func is_harvestable(plant: Plant) -> bool:
	if plant == null or plant.state_machine == null or plant.state_machine.current_state == null:
		return false
	return String(plant.state_machine.current_state.name).to_snake_case() == PlantStateNames.MATURE


static func harvest(plant: Plant, cell: Vector2i) -> bool:
	# Keep harvest as a "virtual tool" so plant logic can stay state-driven.
	if plant == null:
		return false
	# Prevent double-harvest (multiple interaction calls in the same frame).
	if plant.has_meta(&"harvested") and bool(plant.get_meta(&"harvested")):
		return true

	var harvest_tool := ToolData.new()
	harvest_tool.id = &"harvest"
	harvest_tool.display_name = "Harvest"
	harvest_tool.action_kind = Enums.ToolActionKind.HARVEST

	var ok := plant.on_interact(harvest_tool, cell)
	if not ok or not is_instance_valid(plant):
		return ok

	plant.set_meta(&"harvested", true)

	# Remove it from occupancy immediately so subsequent interactions don't see it this frame.
	var occ: Node = plant.get_node_or_null(NodePath("GridOccupantComponent"))
	if occ != null and occ.has_method("unregister_all"):
		occ.call("unregister_all")

	_spawn_harvest_drop(plant)
	if SFXManager != null and _SFX_HARVEST != null:
		SFXManager.play_effect(_SFX_HARVEST, plant.global_position)

	# Ensure plant disappears even if plant state logic is still a stub.
	if not plant.is_queued_for_deletion():
		plant.queue_free()
	return ok


static func _spawn_harvest_drop(plant: Plant) -> void:
	if plant == null or plant.data == null:
		return
	var item := plant.data.harvest_item as ItemData
	if item == null:
		return

	var amount := maxi(1, int(plant.data.loot_amount))
	var drops := maxi(1, int(plant.data.spawn_count))

	var parent := _get_level_entities_root(plant.get_tree())
	if parent == null:
		parent = plant.get_tree().current_scene if plant.get_tree() != null else null
	if parent == null:
		return

	WorldItem.spawn(parent, item, amount, drops, plant.global_position)


static func _get_level_entities_root(tree: SceneTree) -> Node:
	# Mirror LootComponent behavior: drops must be parented under the active LevelRoot subtree
	# so capture/save sees them.
	if tree == null:
		return null
	var scene := tree.current_scene
	if scene is LevelRoot:
		return (scene as LevelRoot).get_entities_root()
	return scene if scene != null else tree.root


func try_interact(ctx: InteractionContext) -> bool:
	if ctx == null:
		return false

	var plant := get_parent() as Plant
	if plant == null or plant.state_machine == null:
		return false

	# Harvest is a hard priority and can be triggered by USE or by any tool press.
	if is_harvestable(plant) and (ctx.is_use() or ctx.is_tool()):
		return harvest(plant, ctx.cell)

	# Non-harvest plant interactions remain tool-only.
	if not ctx.is_tool():
		return false

	if plant.state_machine.current_state is PlantState:
		return (plant.state_machine.current_state as PlantState).on_interact(
			ctx.tool_data, ctx.cell
		)
	return false
