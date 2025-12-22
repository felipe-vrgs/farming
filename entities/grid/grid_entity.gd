class_name GridEntity
extends Node2D

## Defines what "material" or "category" this entity is.
enum EntityType {
	GENERIC = 0,
	PLANT = 1,
	TREE = 2,
	ROCK = 3,
	BUILDING = 4
}

## The generic type of this entity.
@export var entity_type: EntityType = EntityType.GENERIC
## If true, this entity prevents movement/placement on its tile.
@export var blocks_movement: bool = true

var grid_pos: Vector2i

func _ready() -> void:
	_snap_to_grid()
	_register_on_grid()

func _snap_to_grid() -> void:
	# Snap to the center of the grid cell
	grid_pos = TileMapManager.global_to_cell(global_position)
	global_position = TileMapManager.cell_to_global(grid_pos)

func _register_on_grid() -> void:
	GridState.register_entity(grid_pos, self)

func _exit_tree() -> void:
	GridState.unregister_entity(grid_pos, self)

## Virtual method called when a tool interacts with this entity.
func on_interact(_tool_data: ToolData) -> void:
	pass

