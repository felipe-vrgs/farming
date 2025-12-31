class_name LevelRoot
extends Node2D

## Stable identifier for this level (used for per-level save files).
@export var level_id: Enums.Levels = Enums.Levels.NONE

## NodePaths for important level sub-structures.
## Keep defaults matching the current `main.tscn` layout.
@export var ground_layer_path: NodePath = NodePath("GroundMaps/Ground")

## Where non-plant entities should be parented on restore (trees, rocks, NPCs, etc.).
@export var entities_root_path: NodePath = NodePath("GroundMaps/Ground")

func get_ground_layer() -> TileMapLayer:
	return get_node_or_null(ground_layer_path) as TileMapLayer

func get_entities_root() -> Node:
	var n := get_node_or_null(entities_root_path)
	return n if n != null else self

func find_route(route_id: RouteIds.Id) -> Node:
	# Finds a route node (e.g. WaypointRoute) under this level by route_id.
	if route_id == RouteIds.Id.NONE or get_tree() == null:
		return null
	for n in get_tree().get_nodes_in_group(Groups.name(Groups.Id.ROUTES)):
		if not (n is Node):
			continue
		var node := n as Node
		if not is_ancestor_of(node):
			continue
		var rid = node.get("route_id")
		if typeof(rid) == TYPE_INT and rid == int(route_id):
			return node
	return null

func get_route_waypoints_global(route_id: RouteIds.Id) -> Array[Vector2]:
	var r := find_route(route_id)
	if r == null:
		return []
	if r.has_method("get_waypoints_global"):
		return r.call("get_waypoints_global") as Array[Vector2]
	return []

## Roots to scan when capturing entities for saving.
## Default: the entities root only. Farm levels override to include Plants root.
func get_save_entity_roots() -> Array[Node]:
	# Include self so entities not under `entities_root` (e.g. Player/NPCs while we migrate)
	# can still be captured/cleared/restored, while the actual capture filter remains
	# "SaveComponent or persistent_entities group".
	return [self, get_entities_root()]

