class_name FarmLevelRoot
extends LevelRoot

@export var soil_overlay_layer_path: NodePath = NodePath("GroundMaps/SoilOverlay")
@export var wet_overlay_layer_path: NodePath = NodePath("GroundMaps/SoilWetOverlay")

## Optional explicit plants root path. If missing, we create it under GroundMaps.
@export var plants_root_path: NodePath = NodePath("GroundMaps/Plants")

func get_soil_overlay_layer() -> TileMapLayer:
	return get_node_or_null(soil_overlay_layer_path) as TileMapLayer

func get_wet_overlay_layer() -> TileMapLayer:
	return get_node_or_null(wet_overlay_layer_path) as TileMapLayer

func get_or_create_plants_root() -> Node2D:
	var existing := get_node_or_null(plants_root_path)
	if existing is Node2D:
		return existing

	var ground_maps := get_node_or_null(NodePath("GroundMaps"))
	var parent: Node = ground_maps if ground_maps != null else self

	# Create a Plants root for y-sort (mirrors previous GridState behavior).
	var n := Node2D.new()
	n.name = "Plants"
	n.y_sort_enabled = true
	n.z_index = 4
	# IMPORTANT: Avoid `call_deferred` during hydration/travel.
	# If the Plants root isn't in the tree yet, Plants won't `_ready()`,
	# Occupancy won't register, and runtime day ticks won't affect them.
	if parent.is_inside_tree():
		parent.add_child(n)
	else:
		parent.add_child.call_deferred(n)
	return n

func get_plants_root() -> Node2D:
	return get_node_or_null(plants_root_path) as Node2D

func get_save_entity_roots() -> Array[Node]:
	var roots := super.get_save_entity_roots()
	var pr := get_plants_root()
	if pr == null:
		pr = get_or_create_plants_root()
	if pr != null:
		roots.append(pr)
	return roots