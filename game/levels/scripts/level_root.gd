class_name LevelRoot
extends Node2D

## Stable identifier for this level (used for per-level save files).
@export var level_id: Enums.Levels = Enums.Levels.NONE

## Optional per-level audio overrides (leave null to use global defaults).
@export_group("Audio")
@export var music_stream: AudioStream = null
@export var ambience_stream: AudioStream = null

## NodePaths for important level sub-structures.
## Keep defaults matching the current `main.tscn` layout.
@export var ground_layer_path: NodePath = NodePath("GroundMaps/Ground")
@export var obstacle_layer_path: NodePath = NodePath("GroundMaps/Obstacles")

## Where non-plant entities should be parented on restore (trees, rocks, NPCs, etc.).
@export var entities_root_path: NodePath = NodePath("GroundMaps/Entities")

const _DEFAULT_ENTITIES_ROOT := NodePath("GroundMaps/Entities")


func get_ground_layer() -> TileMapLayer:
	return get_node_or_null(ground_layer_path) as TileMapLayer


func get_obstacle_layer() -> TileMapLayer:
	return get_node_or_null(obstacle_layer_path) as TileMapLayer


func get_music_stream() -> AudioStream:
	return music_stream


func get_ambience_stream() -> AudioStream:
	return ambience_stream


func get_entities_root() -> Node:
	var n := get_node_or_null(entities_root_path)
	if n != null:
		return n

	# Back-compat: if older scenes don't have the node, create it under GroundMaps.
	return _get_or_create_entities_root()


func _get_or_create_entities_root() -> Node2D:
	var existing := get_node_or_null(_DEFAULT_ENTITIES_ROOT)
	if existing is Node2D:
		_configure_entities_root(existing as Node2D)
		return existing as Node2D

	var ground_maps := get_node_or_null(NodePath("GroundMaps"))
	var parent: Node = ground_maps if ground_maps != null else self

	var root := Node2D.new()
	root.name = "Entities"
	_configure_entities_root(root)
	parent.add_child(root)

	# Point the exported path at the created node for subsequent calls.
	entities_root_path = _DEFAULT_ENTITIES_ROOT
	return root


func _configure_entities_root(root: Node2D) -> void:
	root.y_sort_enabled = true
	root.z_index = ZLayers.WORLD_ENTITIES
