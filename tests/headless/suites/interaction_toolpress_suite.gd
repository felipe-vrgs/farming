extends RefCounted

## Interaction regression suite for Stardew-like "hard blocker" behavior:
## - Mature plants can be harvested via USE and via any TOOL interaction.

const _PLANT_SCENE := "res://game/entities/plants/plant.tscn"
const _TOMATO_DATA := "res://game/entities/plants/types/tomato.tres"


func register(runner: Node) -> void:
	runner.add_test(
		"interaction_harvest_mature_plant_via_use",
		func() -> void:
			var plant := await _spawn_mature_plant(runner)
			runner._assert_true(plant != null, "Failed to spawn mature plant for test")
			if plant == null:
				return

			var interactable: Node = plant.get_node_or_null(NodePath("PlantInteractable"))
			runner._assert_true(interactable != null, "PlantInteractable missing on Plant scene")
			if interactable == null:
				plant.queue_free()
				return

			var ctx := InteractionContext.new()
			ctx.kind = InteractionContext.Kind.USE
			ctx.actor = null
			ctx.cell = Vector2i.ZERO
			ctx.target = plant

			var ok: bool = bool(interactable.call("try_interact", ctx))
			runner._assert_true(ok, "USE should harvest a mature plant")

			# Let queued frees flush.
			await runner.get_tree().process_frame
			await runner.get_tree().process_frame
			runner._assert_true(
				(
					(not is_instance_valid(plant))
					or (is_instance_valid(plant) and plant.is_queued_for_deletion())
					or (is_instance_valid(plant) and plant.get_parent() == null)
				),
				"Harvested plant should be queued-free or freed after a couple frames"
			)
	)

	runner.add_test(
		"interaction_harvest_mature_plant_via_any_tool",
		func() -> void:
			var plant := await _spawn_mature_plant(runner)
			runner._assert_true(plant != null, "Failed to spawn mature plant for test")
			if plant == null:
				return

			var interactable: Node = plant.get_node_or_null(NodePath("PlantInteractable"))
			runner._assert_true(interactable != null, "PlantInteractable missing on Plant scene")
			if interactable == null:
				plant.queue_free()
				return

			var tool := load("res://game/entities/tools/data/shovel.tres") as ToolData
			runner._assert_true(tool != null, "Failed to load shovel tool for test")
			if tool == null:
				plant.queue_free()
				return

			var ctx := InteractionContext.new()
			ctx.kind = InteractionContext.Kind.TOOL
			ctx.actor = null
			ctx.tool_data = tool
			ctx.cell = Vector2i.ZERO
			ctx.target = plant

			var ok: bool = bool(interactable.call("try_interact", ctx))
			runner._assert_true(ok, "Any tool interaction should harvest a mature plant")

			# Let queued frees flush.
			await runner.get_tree().process_frame
			await runner.get_tree().process_frame
			runner._assert_true(
				(
					(not is_instance_valid(plant))
					or (is_instance_valid(plant) and plant.is_queued_for_deletion())
					or (is_instance_valid(plant) and plant.get_parent() == null)
				),
				"Harvested plant should be queued-free or freed after a couple frames"
			)
	)


func _spawn_mature_plant(runner: Node) -> Plant:
	if not ResourceLoader.exists(_PLANT_SCENE):
		runner._fail("Missing Plant scene for tests: " + _PLANT_SCENE)
		return null
	if not ResourceLoader.exists(_TOMATO_DATA):
		runner._fail("Missing PlantData resource for tests: " + _TOMATO_DATA)
		return null

	var scene := load(_PLANT_SCENE) as PackedScene
	if scene == null:
		runner._fail("Failed to load Plant scene: " + _PLANT_SCENE)
		return null
	var plant := scene.instantiate() as Plant
	if plant == null:
		runner._fail("Plant scene did not instantiate a Plant")
		return null

	var root := runner.get_tree().current_scene
	if root == null:
		root = runner.get_tree().root
	root.add_child(plant)
	await runner.get_tree().process_frame

	var data := load(_TOMATO_DATA) as PlantData
	if data == null:
		runner._fail("Failed to load PlantData: " + _TOMATO_DATA)
		plant.queue_free()
		return null

	plant.data = data
	# Make visuals deterministic for tests (avoid random variant).
	plant.variant_index = 0
	# Make the test deterministic: explicitly force the plant into the MATURE state
	# instead of depending on growth math + visuals initialization order.
	if plant.state_machine != null and plant.state_machine.current_state == null:
		plant.state_machine.init(PlantStateNames.SEED)
	plant.apply_simulated_growth(data.days_to_grow)
	await runner.get_tree().process_frame

	runner._assert_true(
		(
			plant.state_machine != null
			and plant.state_machine.current_state != null
			and (
				String(plant.state_machine.current_state.name).to_snake_case()
				== String(PlantStateNames.MATURE)
			)
		),
		"Plant should be in MATURE state after forcing growth"
	)

	return plant
