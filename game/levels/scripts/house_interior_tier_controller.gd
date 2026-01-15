class_name HouseInteriorTierController
extends Node

@export var entities_root_path: NodePath = NodePath("GroundMaps/Entities")
@export var tier_container_paths: Array[NodePath] = [
	NodePath("GroundMaps/Entities/Tier0"),
	NodePath("GroundMaps/Entities/Tier1"),
	NodePath("GroundMaps/Entities/Tier2"),
]

@export var tier: int = 0:
	get:
		return _tier
	set(value):
		var next = max(0, int(value))
		if _tier == next:
			return
		_tier = next
		if _is_ready:
			_apply_tier(_tier)

var _tier: int = 0
var _is_ready: bool = false
var _entities_root: Node = null
var _tier_containers: Array[Node] = []
var _tier_nodes: Array[Array] = []
var _active_tier: int = -1


func _ready() -> void:
	_is_ready = true
	_cache_tier_nodes()
	_apply_tier(_tier)


func set_tier(next_tier: int) -> void:
	tier = next_tier


func refresh_tiers() -> void:
	_cache_tier_nodes()
	_apply_tier(_tier)


func _cache_tier_nodes() -> void:
	_tier_containers.clear()
	_tier_nodes.clear()

	for path in tier_container_paths:
		var container := _resolve_node(path)
		_tier_containers.append(container)
		var nodes: Array[Node] = []
		if container != null:
			for child in container.get_children():
				if child is Node:
					nodes.append(child)
			if container is CanvasItem:
				(container as CanvasItem).visible = false
			container.process_mode = Node.PROCESS_MODE_DISABLED
		_tier_nodes.append(nodes)


func _apply_tier(next_tier: int) -> void:
	_entities_root = _resolve_entities_root()
	if _entities_root == null:
		push_warning("HouseInteriorTierController: Entities root not found.")
		return
	if _tier_nodes.is_empty():
		push_warning("HouseInteriorTierController: No tier containers configured.")
		return

	var tier_idx := _clamp_tier_index(next_tier)
	if tier_idx == _active_tier:
		return

	if _active_tier == -1:
		for i in range(_tier_nodes.size()):
			if i == tier_idx:
				continue
			_reparent_tier_nodes(i, false)
	elif _active_tier >= 0 and _active_tier < _tier_nodes.size():
		_reparent_tier_nodes(_active_tier, false)

	_reparent_tier_nodes(tier_idx, true)
	_active_tier = tier_idx
	_sort_entities_children_by_y()


func _clamp_tier_index(value: int) -> int:
	return clampi(value, 0, _tier_nodes.size() - 1)


func _reparent_tier_nodes(tier_idx: int, active: bool) -> void:
	var container := _tier_containers[tier_idx]
	var nodes := _tier_nodes[tier_idx]
	if container == null:
		return

	if active:
		for n in nodes:
			if n == null or not is_instance_valid(n):
				continue
			if n.get_parent() != _entities_root:
				n.reparent(_entities_root, true)
			_set_collision_enabled(n, true)
			_set_occupant_enabled(n, true)
	else:
		for n in nodes:
			if n == null or not is_instance_valid(n):
				continue
			if n.get_parent() != container:
				n.reparent(container, true)
			_set_collision_enabled(n, false)
			_set_occupant_enabled(n, false)
		if container is CanvasItem:
			(container as CanvasItem).visible = false
		container.process_mode = Node.PROCESS_MODE_DISABLED


func _set_occupant_enabled(node: Node, enabled: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	var occ := ComponentFinder.find_component_in_group(node, Groups.GRID_OCCUPANT_COMPONENTS)
	if occ != null:
		if enabled and occ.has_method("register_from_current_position"):
			occ.call("register_from_current_position")
		elif not enabled and occ.has_method("unregister_all"):
			occ.call("unregister_all")


func _set_collision_enabled(node: Node, enabled: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	_toggle_collision_recursive(node, enabled)


func _toggle_collision_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionObject2D:
		var obj := node as CollisionObject2D
		if enabled:
			if obj.has_meta("_tier_collision_layer"):
				obj.collision_layer = int(obj.get_meta("_tier_collision_layer"))
				obj.collision_mask = int(obj.get_meta("_tier_collision_mask"))
		else:
			if not obj.has_meta("_tier_collision_layer"):
				obj.set_meta("_tier_collision_layer", obj.collision_layer)
				obj.set_meta("_tier_collision_mask", obj.collision_mask)
			obj.collision_layer = 0
			obj.collision_mask = 0
	elif node is TileMapLayer:
		var layer := node as TileMapLayer
		if enabled:
			if layer.has_meta("_tier_collision_enabled"):
				layer.collision_enabled = bool(layer.get_meta("_tier_collision_enabled"))
		else:
			if not layer.has_meta("_tier_collision_enabled"):
				layer.set_meta("_tier_collision_enabled", layer.collision_enabled)
			layer.collision_enabled = false

	for child in node.get_children():
		if child is Node:
			_toggle_collision_recursive(child as Node, enabled)


func _sort_entities_children_by_y() -> void:
	if _entities_root == null or not is_instance_valid(_entities_root):
		return
	var children := _entities_root.get_children()
	if children.is_empty():
		return

	var containers: Array[Node] = []
	var sortable: Array[Node2D] = []
	for child in children:
		if child is Node and _tier_containers.has(child as Node):
			containers.append(child as Node)
			continue
		if child is Node2D:
			sortable.append(child as Node2D)

	sortable.sort_custom(_compare_node2d_by_y)

	var ordered: Array[Node] = []
	for n in sortable:
		ordered.append(n)
	for n in containers:
		ordered.append(n)

	for i in range(ordered.size()):
		var n := ordered[i]
		if n.get_parent() == _entities_root:
			_entities_root.move_child(n, i)


static func _compare_node2d_by_y(a: Node2D, b: Node2D) -> bool:
	if a == null or b == null:
		return false
	var ay := a.global_position.y
	var by := b.global_position.y
	if ay != by:
		return ay < by
	var ax := a.global_position.x
	var bx := b.global_position.x
	if ax != bx:
		return ax < bx
	return StringName(a.name) < StringName(b.name)


func _resolve_entities_root() -> Node:
	var n := _resolve_node(entities_root_path)
	if n != null:
		return n
	var lr := _resolve_level_root()
	if lr != null:
		return lr.get_entities_root()
	return null


func _resolve_node(path: NodePath) -> Node:
	var n := get_node_or_null(path)
	if n != null:
		return n
	var lr := _resolve_level_root()
	if lr != null:
		return lr.get_node_or_null(path)
	return null


func _resolve_level_root() -> LevelRoot:
	var scene := get_tree().current_scene
	if scene is LevelRoot:
		return scene as LevelRoot
	if scene != null:
		var lr := scene.get_node_or_null(NodePath("LevelRoot"))
		if lr is LevelRoot:
			return lr as LevelRoot
	return null
