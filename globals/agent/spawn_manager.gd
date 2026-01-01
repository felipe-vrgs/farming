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

	# Fallback: group membership can be missing briefly during scene transitions.
	# Scan under the level_root for Marker2D nodes with a `spawn_id` property.
	if found == null:
		var stack: Array[Node] = [level_root]
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur is Marker2D:
				var sidv2 = cur.get("spawn_id")
				if typeof(sidv2) == TYPE_INT and int(sidv2) == int(spawn_id):
					found = cur as Marker2D
					break
			for c in cur.get_children():
				if c is Node:
					stack.append(c as Node)

	return found

func get_spawn_pos(level_root: Node, spawn_id: Enums.SpawnId) -> Vector2:
	# Spawn markers are defined as actor origin (`global_position`) positions.
	var m := find_spawn_marker(level_root, spawn_id)
	return m.global_position if m != null else Vector2.ZERO

func spawn_actor(scene: PackedScene, level_root: LevelRoot, spawn_id: Enums.SpawnId) -> Node2D:
	if scene == null or level_root == null:
		return null
	var node := scene.instantiate()
	if not (node is Node2D):
		node.queue_free()
		return null

	# Place BEFORE entering the tree so `_ready()` sees final position.
	var pos := get_spawn_pos(level_root, spawn_id)
	node.global_position = pos

	var parent: Node = level_root.get_entities_root()
	parent.add_child(node)

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


