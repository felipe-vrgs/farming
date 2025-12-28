class_name EntityCapture
extends Object

static func capture_entities(grid_state: Node) -> Array[EntitySnapshot]:
	var out: Array[EntitySnapshot] = []
	if grid_state == null:
		return out

	# Dedupe by instance id (important for multi-cell entities like trees).
	var seen := {}
	var grid_data = grid_state.get("_grid_data")
	if grid_data == null:
		return out

	for cell in grid_data:
		var data: GridCellData = grid_data[cell]
		if data == null:
			continue

		for type_key in data.entities:
			var entity = data.entities[type_key]
			if entity == null or not is_instance_valid(entity):
				continue
			var id: int = entity.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true

			var snap := EntitySnapshot.new()
			snap.scene_path = entity.scene_file_path
			snap.persistent_id = _get_persistent_id(entity)
			snap.grid_pos = cell
			snap.entity_type = int(type_key)
			# Capture State
			var captured := false
			if entity.has_method("get_save_state"):
				snap.state = entity.get_save_state()
				captured = true

			if not captured:
				var save_comp = entity.get_node_or_null("SaveComponent")
				if save_comp and save_comp.has_method("get_save_state"):
					snap.state = save_comp.get_save_state()
					captured = true

			if not captured:
				snap.state = {}

			out.append(snap)

	return out

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


