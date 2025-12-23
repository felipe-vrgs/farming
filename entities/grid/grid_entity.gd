class_name GridEntity
extends Node2D

## The generic type of this entity.
@export var entity_type: Enums.EntityType = Enums.EntityType.GENERIC
## If true, this entity prevents movement/placement on its tile.
@export var blocks_movement: bool = true

@export_group("Loot")
## What item to drop when destroyed.
@export var loot_item: ItemData
## How many items to drop.
@export var loot_count: int = 1

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

## Generic destruction method. Handles grid unregistration and loot spawning.
func destroy() -> void:
	_spawn_loot()
	queue_free()

func _spawn_loot() -> void:
	if loot_item == null:
		return

	var world_item_scene = load("res://entities/items/world_item.tscn")
	for i in range(loot_count):
		var item = world_item_scene.instantiate()
		item.item_data = loot_item
		# Random offset so items don't stack perfectly on top of each other
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		item.global_position = global_position + offset
		get_parent().add_child(item)
