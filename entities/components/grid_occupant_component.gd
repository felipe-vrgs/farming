class_name GridOccupantComponent
extends Node

## The generic type of this entity.
@export var entity_type: Enums.EntityType = Enums.EntityType.GENERIC

@export var auto_register_on_ready: bool = true
@export var collision_shape: CollisionShape2D = null

# The grid position(s) this occupant is registered at.
# Useful for debugging or cleanup if needed.
var _registered_cells: Array[Vector2i] = []

func _enter_tree() -> void:
	add_to_group(Groups.GRID_OCCUPANT_COMPONENTS)

func _ready() -> void:
	if auto_register_on_ready:
		register_from_current_position()

func _exit_tree() -> void:
	unregister_all()

func register_from_current_position() -> void:
	unregister_all()
	var parent := get_parent()
	if parent == null:
		push_warning("GridOccupantComponent has no parent to register.")
		return
	if WorldGrid.tile_map == null:
		push_warning("GridOccupantComponent: WorldGrid.tile_map is missing; cannot register.")
		return

	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		var shape := collision_shape.shape as RectangleShape2D
		var position := collision_shape.global_position
		var size := shape.size
		var rect := Rect2(position - size * 0.5, size)
		_register_rect_shape(rect)
		return

	var pos := Vector2.ZERO
	if parent is Node2D:
		pos = (parent as Node2D).global_position
	else:
		pos = parent.global_position
	register_at(WorldGrid.tile_map.global_to_cell(pos))

func _register_rect_shape(rect: Rect2) -> void:
	# Avoid inclusive edge turning into an extra cell when perfectly aligned.
	var start_cell := WorldGrid.tile_map.global_to_cell(rect.position)
	var end_cell := WorldGrid.tile_map.global_to_cell(rect.end - Vector2(0.001, 0.001))

	for x in range(start_cell.x, end_cell.x + 1):
		for y in range(start_cell.y, end_cell.y + 1):
			register_at(Vector2i(x, y))

func register_at(cell: Vector2i) -> void:
	var parent = get_parent()
	if not parent:
		push_warning("GridOccupantComponent has no parent to register.")
		return

	WorldGrid.register_entity(cell, parent, entity_type)
	if not _registered_cells.has(cell):
		_registered_cells.append(cell)

func unregister_at(cell: Vector2i) -> void:
	var parent = get_parent()
	if parent:
		WorldGrid.unregister_entity(cell, parent, entity_type)
	_registered_cells.erase(cell)

func unregister_all() -> void:
	var parent = get_parent()
	if not parent:
		_registered_cells.clear()
		return
	for cell in _registered_cells:
		WorldGrid.unregister_entity(cell, parent, entity_type)
	_registered_cells.clear()

func get_registered_cells() -> Array[Vector2i]:
	return _registered_cells
