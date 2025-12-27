class_name EntitySerializer
extends Object

const DEFAULT_ENTITY_PARENT_PATH := NodePath("GroundMaps/Ground")

static func capture_entities(grid_state: Node) -> Array[EntitySnapshot]:
	var out: Array[EntitySnapshot] = []
	if grid_state == null:
		return out

	# Dedupe by instance id (important for multi-cell entities like trees).
	var seen := {}
	# Access _grid_data directly as in original code
	var grid_data = grid_state.get("_grid_data")
	if grid_data == null:
		return out

	for cell in grid_data:
		var data: GridCellData = grid_data[cell]
		if data == null:
			continue

		# data.entities is Dictionary[EntityType, Node]
		for type_key in data.entities:
			var entity = data.entities[type_key]
			if entity == null or not is_instance_valid(entity):
				continue
			var id: int = entity.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true

			var snap := EntitySnapshot.new()
			if entity.has_method("get_save_scene_path"):
				snap.scene_path = entity.get_save_scene_path()
			else:
				snap.scene_path = entity.scene_file_path

			# Determine grid position
			if entity is Node2D:
				snap.grid_pos = TileMapManager.global_to_cell(entity.global_position)
			else:
				snap.grid_pos = cell

			snap.entity_type = int(type_key)
			if entity.has_method("get_save_state"):
				snap.state = entity.get_save_state()
			else:
				snap.state = {}

			out.append(snap)

	return out

static func clear_runtime_entities(grid_state: Node) -> void:
	if grid_state == null:
		return

	# Collect entities to free from GridState
	# This avoids relying on groups which might be missing (e.g. for Tree)
	var entities_to_free := {}
	var grid_data = grid_state.get("_grid_data")

	if grid_data:
		for cell in grid_data:
			var data = grid_data[cell]
			if data and data.entities:
				for entity in data.entities.values():
					if is_instance_valid(entity):
						entities_to_free[entity.get_instance_id()] = entity

	# Free them
	for entity in entities_to_free.values():
		if entity is Node:
			entity.queue_free()

static func restore_entities(grid_state: Node, entities: Array[EntitySnapshot]) -> bool:
	if grid_state == null:
		return false

	var scene := grid_state.get_tree().current_scene
	if scene == null:
		return false

	var entity_parent: Node = scene.get_node_or_null(DEFAULT_ENTITY_PARENT_PATH)
	if entity_parent == null:
		entity_parent = scene

	# Plants go under Plants root for y-sort; ensure it's ready.
	var plants_root = null
	if grid_state.has_method("_get_or_create_plants_root"):
		plants_root = grid_state._get_or_create_plants_root(scene)
	elif grid_state.get("_plants_root"):
		plants_root = grid_state.get("_plants_root")

	for es in entities:
		if es == null:
			continue

		var scene_path := String(es.scene_path)
		if scene_path.is_empty():
			continue

		var packed = load(scene_path)
		if not (packed is PackedScene):
			push_warning("SaveLoad: Could not load PackedScene at '%s'" % scene_path)
			continue

		var node = packed.instantiate()
		if not (node is Node2D):
			node.queue_free()
			continue

		# Position
		node.global_position = TileMapManager.cell_to_global(es.grid_pos)

		# Apply state
		if node.has_method("apply_save_state"):
			node.apply_save_state(es.state)

		# Parent selection
		var parent: Node = entity_parent
		if es.entity_type == Enums.EntityType.PLANT and plants_root != null:
			parent = plants_root

		parent.add_child(node)

	return true
