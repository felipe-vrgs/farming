class_name EntityCapture
extends Object

const PERSISTENT_GROUP := &"persistent_entities"
const _SAVE_COMP_GROUP := &"save_components"
const _OCC_COMP_GROUP := &"grid_occupant_components"

static func _find_component_in_group(entity: Node, group_name: StringName) -> Node:
	if entity == null:
		return null

	# Only treat a component as "owned by this entity" if it's a direct child,
	# or a child of the conventional `Components/` container.
	for child in entity.get_children():
		if child is Node and (child as Node).is_in_group(group_name):
			return child as Node

	var components := entity.get_node_or_null(NodePath("Components"))
	if components is Node:
		for child in (components as Node).get_children():
			if child is Node and (child as Node).is_in_group(group_name):
				return child as Node

	return null

static func _get_save_component(entity: Node) -> Node:
	if entity == null:
		return null
	return _find_component_in_group(entity, _SAVE_COMP_GROUP)

static func _get_occupant_component(entity: Node) -> Node:
	if entity == null:
		return null
	return _find_component_in_group(entity, _OCC_COMP_GROUP)

static func capture_entities(level_root: LevelRoot) -> Array[EntitySnapshot]:
	var out: Array[EntitySnapshot] = []
	if level_root == null:
		return out

	var roots: Array[Node] = []
	if level_root.has_method("get_save_entity_roots"):
		roots = level_root.get_save_entity_roots()
	else:
		roots = [level_root.get_entities_root()]

	# Dedupe by instance id (important for multi-cell entities like trees).
	var seen := {}
	for r in roots:
		_scan_save_root(r, out, seen)

	return out

static func _scan_save_root(root: Node, out: Array[EntitySnapshot], seen: Dictionary) -> void:
	if root == null:
		return
	_scan_node_recursive(root, out, seen)

static func _scan_node_recursive(n: Node, out: Array[EntitySnapshot], seen: Dictionary) -> void:
	if n == null:
		return

	# Capture entities as Node2D only (we don't save components/utility nodes directly).
	if n is Node2D:
		var entity := n as Node2D
		if _is_saveable_entity(entity):
			var id := entity.get_instance_id()
			if not seen.has(id):
				seen[id] = true
				var snap := _make_snapshot(entity)
				if snap != null:
					out.append(snap)

	for c in n.get_children():
		_scan_node_recursive(c, out, seen)

static func _is_saveable_entity(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	# Never save level scenes as entities.
	if entity is LevelRoot:
		return false

	# Always include persistent entities so reconciliation works even if they have no SaveComponent.
	if (entity as Node).is_in_group(PERSISTENT_GROUP):
		return true

	# Prefer SaveComponent contract.
	var save_comp = _get_save_component(entity)
	if save_comp != null and save_comp.has_method("get_save_state"):
		return true

	return false

static func _make_snapshot(entity: Node2D) -> EntitySnapshot:
	if entity == null:
		return null

	var scene_path := String(entity.scene_file_path)
	if scene_path.is_empty():
		# Without a scene path we can't re-instantiate this entity.
		# (Persistent entities still reconcile by PID, but we still need the scene path for dynamic ones.)
		if not (entity as Node).is_in_group(PERSISTENT_GROUP):
			return null

	var snap := EntitySnapshot.new()
	snap.scene_path = scene_path
	snap.persistent_id = _get_persistent_id(entity)
	var pos := Vector2i.ZERO
	if TileMapManager != null:
		pos = TileMapManager.global_to_cell(entity.global_position)
	snap.grid_pos = pos

	# Entity type: prefer GridOccupantComponent if present.
	var occ = _get_occupant_component(entity)
	if occ is GridOccupantComponent:
		snap.entity_type = int((occ as GridOccupantComponent).entity_type)
	else:
		snap.entity_type = 0

	# Capture State (prefer SaveComponent to standardize contract).
	var captured := false
	var save_comp = _get_save_component(entity)
	if save_comp != null and save_comp.has_method("get_save_state"):
		snap.state = save_comp.get_save_state()
		captured = true

	if not captured:
		snap.state = {}

	return snap

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
