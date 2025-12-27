class_name EntitySerializer
extends Object

const DEFAULT_ENTITY_PARENT_PATH := NodePath("GroundMaps/Ground")

static func capture_entities(grid_state: Node) -> Array[EntitySnapshot]:
	var out: Array[EntitySnapshot] = []
	if grid_state == null:
		return out

	# Dedupe by instance id (important for multi-cell entities like trees).
	var seen := {}
	for cell in grid_state._grid_data:
		var data: GridCellData = grid_state._grid_data[cell]
		if data == null:
			continue
		for entity in data.grid_entities.values():
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
			snap.grid_pos = entity.grid_pos
			snap.entity_type = int(entity.entity_type)
			snap.state = entity.get_save_state() if entity.has_method("get_save_state") else {}
			out.append(snap)

	return out

static func clear_runtime_entities(tree: SceneTree) -> void:
	if tree == null:
		return
	var existing_entities := tree.get_nodes_in_group(&"grid_entities")
	for e in existing_entities:
		if e is GridEntity:
			# Remove from grid state first to prevent lingering references
			var grid_entity = e as GridEntity
			GridState.unregister_entity(grid_entity.grid_pos, grid_entity)
			(e as Node).queue_free()

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
	grid_state._plants_root = grid_state._get_or_create_plants_root(scene)

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

		var node = (packed as PackedScene).instantiate()
		if not (node is GridEntity):
			node.queue_free()
			continue

		var ge := node as GridEntity
		ge.global_position = TileMapManager.cell_to_global(es.grid_pos)

		# Apply state (entities can defer internally if they rely on onready vars).
		if ge.has_method("apply_save_state"):
			ge.apply_save_state(es.state)

		var parent: Node = grid_state._plants_root if (ge is Plant) else entity_parent
		parent.add_child(ge)

	return true


