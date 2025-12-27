class_name GridEntity
extends Node2D

## The generic type of this entity.
@export var entity_type: Enums.EntityType = Enums.EntityType.GENERIC
## If true, this entity is an obstacle.
@export var is_obstacle: bool = false

var grid_pos: Vector2i

func _ready() -> void:
	_snap_to_grid()
	_register_on_grid()
	add_to_group(&"grid_entities")

func _snap_to_grid() -> void:
	# Snap to the center of the grid cell
	grid_pos = TileMapManager.global_to_cell(global_position)
	global_position = TileMapManager.cell_to_global(grid_pos)

func _register_on_grid() -> void:
	GridState.register_entity(grid_pos, self)

func _exit_tree() -> void:
	GridState.unregister_entity(grid_pos, self)

## Virtual method called when a tool interacts with this entity.
func on_interact(_tool_data: ToolData, _cell: Vector2i = Vector2i.ZERO) -> bool:
	return false

## Returns the PackedScene path used to re-instantiate this entity on load.
## Default: Node's scene file path (works for instanced scenes).
func get_save_scene_path() -> String:
	return scene_file_path

## Returns entity-specific state to persist.
func get_save_state() -> Dictionary:
	return {}

## Applies entity-specific state loaded from disk.
## Called during load; implementations should be resilient if called before/after _ready().
func apply_save_state(_state: Dictionary) -> void:
	pass
