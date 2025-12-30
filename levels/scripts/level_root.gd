class_name LevelRoot
extends Node2D

## Stable identifier for this level (used for per-level save files).
@export var level_id: StringName = &""

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

## Roots to scan when capturing entities for saving.
## Default: the entities root only. Farm levels override to include Plants root.
func get_save_entity_roots() -> Array[Node]:
	return [get_entities_root()]

