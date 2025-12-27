class_name GridOccupantComponent
extends Node

## The generic type of this entity.
@export var entity_type: Enums.EntityType = Enums.EntityType.GENERIC

# The grid position(s) this occupant is registered at.
# Useful for debugging or cleanup if needed.
var _registered_cells: Array[Vector2i] = []

func _ready() -> void:
	pass

func _exit_tree() -> void:
	unregister_all()

func register_at(cell: Vector2i) -> void:
	var parent = get_parent()
	if not parent:
		push_warning("GridOccupantComponent has no parent to register.")
		return

	GridState.register_entity(cell, parent, entity_type)
	if not _registered_cells.has(cell):
		_registered_cells.append(cell)

func unregister_at(cell: Vector2i) -> void:
	var parent = get_parent()
	if parent:
		GridState.unregister_entity(cell, parent, entity_type)
	_registered_cells.erase(cell)

func unregister_all() -> void:
	var parent = get_parent()
	if not parent:
		_registered_cells.clear()
		return

	for cell in _registered_cells:
		GridState.unregister_entity(cell, parent, entity_type)
	_registered_cells.clear()

func get_registered_cells() -> Array[Vector2i]:
	return _registered_cells