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
	parent.add_child.call_deferred(n)
	return n
