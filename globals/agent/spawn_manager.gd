extends Node

## Global spawn orchestration for Player/NPCs.
## - Spawn markers are authored per-level via SpawnMarker nodes with `spawn_id`.
## - Save/Load restores entity positions via SaveComponent.
## - Spawn markers are for "entry points" (new game / travel).

func find_spawn_marker(level_root: Node, spawn_id: Enums.SpawnId) -> Marker2D:
	if level_root == null or spawn_id == Enums.SpawnId.NONE:
		return null
	if level_root.get_tree() == null:
		return null

	# Avoid hard dependency on the SpawnMarker class existing at parse time.
	# We rely on the "spawn_markers" group + `spawn_id` exported property.
	var found: Marker2D = null
	for n in level_root.get_tree().get_nodes_in_group(Groups.SPAWN_MARKERS):
		if not (n is Marker2D):
			continue
		if not level_root.is_ancestor_of(n):
			continue
		var sidv = n.get("spawn_id")
		if typeof(sidv) != TYPE_INT:
			continue
		var sid: int = int(sidv)
		if sid != int(spawn_id):
			continue

		if found == null:
			found = n as Marker2D
		else:
			var msg := "SpawnManager: Duplicate spawn marker for spawn_id=%s under level '%s'" % [
				str(spawn_id),
				str(level_root.name),
			]
			msg += " keep=%s dupe=%s" % [
				str(found.get_path()),
				str((n as Node).get_path()),
			]
			push_warning(msg)
			# Keep the first one found.

	return found

func get_spawn_pos(level_root: Node, spawn_id: Enums.SpawnId) -> Vector2:
	var m := find_spawn_marker(level_root, spawn_id)
	return m.global_position if m != null else Vector2.ZERO

func spawn_actor(scene: PackedScene, level_root: LevelRoot, spawn_id: Enums.SpawnId) -> Node2D:
	if scene == null or level_root == null:
		return null
	var node := scene.instantiate()
	if not (node is Node2D):
		node.queue_free()
		return null

	var parent: Node = level_root.get_entities_root()
	parent.add_child(node)

	var pos := get_spawn_pos(level_root, spawn_id)
	(node as Node2D).global_position = pos
	return node as Node2D

func move_actor_to_spawn(actor: Node2D, level_root: LevelRoot, spawn_id: Enums.SpawnId) -> bool:
	if actor == null or level_root == null or spawn_id == Enums.SpawnId.NONE:
		return false
	var m := find_spawn_marker(level_root, spawn_id)
	if m == null:
		push_warning("SpawnManager: Missing SpawnMarker for spawn_id=%s in level '%s'" % [
			str(spawn_id),
			str(level_root.name),
		])
		return false
	actor.global_position = m.global_position
	return true


