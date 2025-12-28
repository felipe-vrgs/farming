class_name LevelRoot
extends Node2D

## Stable identifier for this level (used for per-level save files).
@export var level_id: StringName = &""

## NodePaths for important level sub-structures.
## Keep defaults matching the current `main.tscn` layout.
@export var ground_layer_path: NodePath = NodePath("GroundMaps/Ground")
@export var soil_overlay_layer_path: NodePath = NodePath("GroundMaps/SoilOverlay")
@export var wet_overlay_layer_path: NodePath = NodePath("GroundMaps/SoilWetOverlay")

## Where non-plant entities should be parented on restore (trees, rocks, NPCs, etc.).
@export var entities_root_path: NodePath = NodePath("GroundMaps/Ground")

## Optional explicit plants root path. If missing, we create it under GroundMaps.
@export var plants_root_path: NodePath = NodePath("GroundMaps/Plants")

func get_ground_layer() -> TileMapLayer:
	return get_node_or_null(ground_layer_path) as TileMapLayer

func get_soil_overlay_layer() -> TileMapLayer:
	return get_node_or_null(soil_overlay_layer_path) as TileMapLayer

func get_wet_overlay_layer() -> TileMapLayer:
	return get_node_or_null(wet_overlay_layer_path) as TileMapLayer

func get_entities_root() -> Node:
	var n := get_node_or_null(entities_root_path)
	return n if n != null else self

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
	parent.add_child(n)
	return n


