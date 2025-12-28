class_name EntityHydrator
extends Object

const DEFAULT_ENTITY_PARENT_PATH := NodePath("GroundMaps/Ground")
const PERSISTENT_GROUP := &"persistent_entities"

static func clear_dynamic_entities(grid_state: Node) -> void:
	if grid_state == null:
		return

	var entities_to_free := {}
	var grid_data = grid_state.get("_grid_data")
	if grid_data:
		for cell in grid_data:
			var data = grid_data[cell]
			if data and data.entities:
				for entity in data.entities.values():
					if is_instance_valid(entity):
						# Don't delete editor-placed persistent entities; they get reconciled.
						if entity is Node and (entity as Node).is_in_group(PERSISTENT_GROUP):
							continue
						entities_to_free[entity.get_instance_id()] = entity

	for entity in entities_to_free.values():
		if entity is Node:
			(entity as Node).queue_free()

static func hydrate_entities(grid_state: Node, entities: Array[EntitySnapshot]) -> bool:
	if grid_state == null:
		return false

	var scene := grid_state.get_tree().current_scene
	if scene == null:
		return false

	# Prefer LevelRoot contract (multi-scene ready).
	var level_root = null
	if scene is LevelRoot:
		level_root = scene
	else:
		level_root = scene.get_node_or_null(NodePath("LevelRoot"))

	var entity_parent: Node = null
	if level_root is LevelRoot:
		entity_parent = (level_root as LevelRoot).get_entities_root()
	else:
		entity_parent = scene.get_node_or_null(DEFAULT_ENTITY_PARENT_PATH)
		if entity_parent == null:
			entity_parent = scene

	# Plants go under Plants root for y-sort; ensure it's ready.
	var plants_root = null
	if grid_state.has_method("_get_or_create_plants_root"):
		plants_root = grid_state._get_or_create_plants_root(scene)
	elif grid_state.get("_plants_root"):
		plants_root = grid_state.get("_plants_root")

	# Build a map of existing persistent entities by id to reconcile against editor-placed nodes.
	# We use an array per PID to handle accidental duplicate IDs gracefully.
	var existing_persistent: Dictionary = {} # StringName -> Array[Node2D]
	for n in scene.get_tree().get_nodes_in_group(PERSISTENT_GROUP):
		if not (n is Node2D):
			continue
		var pid := _get_persistent_id(n)
		if String(pid).is_empty():
			continue
		if not existing_persistent.has(pid):
			existing_persistent[pid] = []
		existing_persistent[pid].append(n)

	# Track which specific node instances were reconciled.
	var reconciled_instance_ids := {}

	for es in entities:
		if es == null:
			continue

		var scene_path := String(es.scene_path)
		if scene_path.is_empty():
			continue

		# Reconcile editor-placed persistent entities by id (avoid duplicates).
		var pid: StringName = es.persistent_id
		if not String(pid).is_empty() and existing_persistent.has(pid):
			var nodes: Array = existing_persistent[pid]
			if not nodes.is_empty():
				var node_existing: Node2D = nodes.pop_front() as Node2D
				reconciled_instance_ids[node_existing.get_instance_id()] = true

				# Baseline-wins: keep authored position; only apply state.
				var authored_in_scene := true
				var comp = node_existing.get_node_or_null(NodePath("PersistentEntityComponent"))
				if comp is PersistentEntityComponent:
					authored_in_scene = (comp as PersistentEntityComponent).authored_in_scene
				if not authored_in_scene:
					node_existing.global_position = TileMapManager.cell_to_global(es.grid_pos)

				# Apply state.
				if node_existing.has_method("apply_save_state"):
					node_existing.apply_save_state(es.state)
				else:
					var save_comp = node_existing.get_node_or_null("SaveComponent")
					if save_comp and save_comp.has_method("apply_save_state"):
						save_comp.apply_save_state(es.state)

				# Re-register because terrain hydration clears `_grid_data`.
				_refresh_grid_registration(node_existing)
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
		(node as Node2D).global_position = TileMapManager.cell_to_global(es.grid_pos)

		# Carry persistent id if present (future dynamic persistables).
		if not String(pid).is_empty():
			var c = node.get_node_or_null(NodePath("PersistentEntityComponent"))
			if c is PersistentEntityComponent:
				(c as PersistentEntityComponent).persistent_id = pid

		# Apply state
		if node.has_method("apply_save_state"):
			node.apply_save_state(es.state)
		else:
			var save_comp = node.get_node_or_null("SaveComponent")
			if save_comp and save_comp.has_method("apply_save_state"):
				save_comp.apply_save_state(es.state)

		# Parent selection
		var parent: Node = entity_parent
		if es.entity_type == Enums.EntityType.PLANT and plants_root != null:
			parent = plants_root

		parent.add_child(node)

	# 3) Cleanup persistent entities that were in the level scene but NOT in the save data.
	# This handles cases where authored entities (like trees) were destroyed/removed.
	# We iterate over the actual nodes in the group to ensure nothing is missed.
	for n in scene.get_tree().get_nodes_in_group(PERSISTENT_GROUP):
		if not reconciled_instance_ids.has(n.get_instance_id()):
			if is_instance_valid(n):
				n.queue_free()

	return true

static func _get_persistent_id(entity: Node) -> StringName:
	if entity == null:
		return &""
	var c = entity.get_node_or_null(NodePath("PersistentEntityComponent"))
	if c is PersistentEntityComponent:
		return (c as PersistentEntityComponent).persistent_id
	if entity.has_method("get_persistent_id"):
		var v = entity.call("get_persistent_id")
		if v is StringName:
			return v
		if v is String:
			return StringName(v)
	return &""

static func _refresh_grid_registration(entity: Node2D) -> void:
	if entity == null:
		return
	if entity.has_method("_register_on_grid"):
		entity.call("_register_on_grid")
		return
	if entity.has_method("register_on_grid"):
		entity.call("register_on_grid")
		return

	var occ = entity.get_node_or_null(NodePath("GridOccupantComponent"))
	if occ is GridOccupantComponent:
		(occ as GridOccupantComponent).unregister_all()
		var cell := TileMapManager.global_to_cell(entity.global_position)
		(occ as GridOccupantComponent).register_at(cell)


