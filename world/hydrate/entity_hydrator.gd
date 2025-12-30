class_name EntityHydrator
extends Object

const DEFAULT_ENTITY_PARENT_PATH := NodePath("GroundMaps/Ground")
const PERSISTENT_GROUP := Groups.PERSISTENT_ENTITIES
const _SAVE_COMP_GROUP := Groups.SAVE_COMPONENTS
const _OCC_COMP_GROUP := Groups.GRID_OCCUPANT_COMPONENTS

static func _get_save_component(entity: Node) -> Node:
	if entity == null:
		return null
	# Primary: group-based discovery (runtime, after _enter_tree()).
	var c := ComponentFinder.find_component_in_group(entity, _SAVE_COMP_GROUP)
	if c != null:
		return c

	# Fallback: during hydration we apply save state BEFORE adding the entity to the tree,
	# so `_enter_tree()` hasn't run and group membership isn't set yet.
	for child in entity.get_children():
		if child is SaveComponent:
			return child as Node
	var components := entity.get_node_or_null(NodePath("Components"))
	if components is Node:
		for child in (components as Node).get_children():
			if child is SaveComponent:
				return child as Node

	return null

static func _get_occupant_component(entity: Node) -> Node:
	if entity == null:
		return null
	# Primary: group-based discovery (runtime, after _enter_tree()).
	var c := ComponentFinder.find_component_in_group(entity, _OCC_COMP_GROUP)
	if c != null:
		return c

	# Fallback: hydration-time lookup before `_enter_tree()` runs.
	for child in entity.get_children():
		if child is GridOccupantComponent:
			return child as Node
	var components := entity.get_node_or_null(NodePath("Components"))
	if components is Node:
		for child in (components as Node).get_children():
			if child is GridOccupantComponent:
				return child as Node

	return null

static func clear_dynamic_entities(level_root: LevelRoot) -> void:
	if level_root == null:
		return

	var roots: Array[Node] = []
	if level_root.has_method("get_save_entity_roots"):
		roots = level_root.get_save_entity_roots()
	else:
		roots = [level_root.get_entities_root()]

	var entities_to_free := {}
	for r in roots:
		_collect_dynamic_saveables(r, entities_to_free)

	for entity in entities_to_free.values():
		if entity is Node:
			(entity as Node).queue_free()

static func _collect_dynamic_saveables(n: Node, entities_to_free: Dictionary) -> void:
	if n == null:
		return

	if n is Node2D:
		var node2d := n as Node2D
		# Don't delete editor-placed persistent entities; they get reconciled/cleaned later.
		if not (node2d as Node).is_in_group(PERSISTENT_GROUP):
			# Only clear nodes that are intended to be saved/restored.
			var save_comp = _get_save_component(node2d)
			if save_comp != null and save_comp.has_method("get_save_state"):
				entities_to_free[node2d.get_instance_id()] = node2d

	for c in n.get_children():
		_collect_dynamic_saveables(c, entities_to_free)

static func hydrate_entities(level_root: LevelRoot, entities: Array[EntitySnapshot]) -> bool:
	if level_root == null:
		return false

	var scene := level_root.get_tree().current_scene
	if scene == null:
		return false

	var entity_parent: Node = null
	if level_root is LevelRoot:
		entity_parent = (level_root as LevelRoot).get_entities_root()
	else:
		entity_parent = scene.get_node_or_null(DEFAULT_ENTITY_PARENT_PATH)
		if entity_parent == null:
			entity_parent = scene

	# Plants go under Plants root for y-sort; ensure it's ready.
	var plants_root = null
	if level_root is FarmLevelRoot:
		plants_root = (level_root as FarmLevelRoot).get_or_create_plants_root()

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
		# Safety: never hydrate a level scene as an entity (prevents "level inside level" corruption).
		if scene_path.begins_with("res://levels/"):
			push_warning("SaveLoad: Skipping forbidden entity scene '%s'" % scene_path)
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

				# Apply state (standardized on SaveComponent).
				var save_comp = _get_save_component(node_existing)
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
		if node is LevelRoot:
			push_warning("SaveLoad: Skipping forbidden LevelRoot entity '%s'" % scene_path)
			node.queue_free()
			continue

		# Parent selection
		var parent: Node = entity_parent
		if es.entity_type == Enums.EntityType.PLANT and plants_root != null:
			parent = plants_root

		# Add first so any apply_save_state implementations that require the tree won't break.
		parent.add_child(node)

		# Position
		(node as Node2D).global_position = TileMapManager.cell_to_global(es.grid_pos)

		# Carry persistent id if present (future dynamic persistables).
		if not String(pid).is_empty():
			var c = node.get_node_or_null(NodePath("PersistentEntityComponent"))
			if c is PersistentEntityComponent:
				(c as PersistentEntityComponent).persistent_id = pid

		# Apply state (standardized on SaveComponent).
		var save_comp = _get_save_component(node)
		if save_comp and save_comp.has_method("apply_save_state"):
			save_comp.apply_save_state(es.state)

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
	# Preferred: component discovered by group (supports component under `Components/`).
	var c = ComponentFinder.find_component_in_group(entity, Groups.PERSISTENT_ENTITY_COMPONENTS)
	if c is PersistentEntityComponent:
		return (c as PersistentEntityComponent).persistent_id

	# Fallback: legacy scenes may still have the component as a direct named child.
	c = entity.get_node_or_null(NodePath("PersistentEntityComponent"))
	if c is PersistentEntityComponent:
		return (c as PersistentEntityComponent).persistent_id
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

	var occ = _get_occupant_component(entity)
	if occ is GridOccupantComponent:
		(occ as GridOccupantComponent).unregister_all()
		(occ as GridOccupantComponent).register_from_current_position()


