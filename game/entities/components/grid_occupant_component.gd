@tool
class_name GridOccupantComponent
extends Node

## The generic type of this entity.
@export var entity_type: Enums.EntityType = Enums.EntityType.GENERIC

@export var auto_register_on_ready: bool = true
@export var collision_shape: CollisionShape2D = null

# The grid position(s) this occupant is registered at.
# Useful for debugging or cleanup if needed.
var _registered_cells: Array[Vector2i] = []


static func _is_tool_placeholder(obj: Object) -> bool:
	# In tool scripts (editor), non-tool scripts can instantiate as placeholders.
	# Calling script methods on placeholders errors:
	# "Attempt to call a method on a placeholder instance".
	if obj == null:
		return false
	if not Engine.is_editor_hint():
		return false
	var scr: Variant = obj.get_script()
	if scr == null:
		return true
	return scr is Script and not (scr as Script).is_tool()


func _enter_tree() -> void:
	add_to_group(Groups.GRID_OCCUPANT_COMPONENTS)


func _ready() -> void:
	# In the editor (tool mode), autoload singletons like WorldGrid can be placeholders.
	# Avoid calling into them from tool scripts to prevent:
	# "Attempt to call a method on a placeholder instance".
	if Engine.is_editor_hint():
		return
	if auto_register_on_ready:
		register_from_current_position()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	unregister_all()


func register_from_current_position() -> void:
	if Engine.is_editor_hint():
		return
	# If WorldGrid isn't bound yet (during scene loads), enqueue a single retry.
	if (
		WorldGrid == null
		or _is_tool_placeholder(WorldGrid)
		or WorldGrid.tile_map == null
		or WorldGrid.occupancy == null
		or not WorldGrid.tile_map.ensure_initialized()
		or not WorldGrid.occupancy.ensure_initialized()
	):
		if (
			WorldGrid != null
			and not _is_tool_placeholder(WorldGrid)
			and WorldGrid.has_method("queue_occupant_registration")
		):
			WorldGrid.queue_occupant_registration(self)
		return

	unregister_all()
	var parent := get_parent()
	if parent == null:
		push_warning("GridOccupantComponent has no parent to register.")
		return

	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		var shape := collision_shape.shape as RectangleShape2D
		var position := collision_shape.global_position
		# IMPORTANT:
		# CollisionShape2D scaling affects physics, but RectangleShape2D.size does not include it.
		# Account for node scale so grid footprint matches the actual collision in-world.
		var s := collision_shape.global_scale
		var size := Vector2(shape.size.x * absf(s.x), shape.size.y * absf(s.y))
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

	if WorldGrid == null or _is_tool_placeholder(WorldGrid):
		return
	WorldGrid.register_entity(cell, parent, entity_type)
	if not _registered_cells.has(cell):
		_registered_cells.append(cell)


func unregister_at(cell: Vector2i) -> void:
	var parent = get_parent()
	if parent:
		if WorldGrid == null or _is_tool_placeholder(WorldGrid):
			_registered_cells.erase(cell)
			return
		WorldGrid.unregister_entity(cell, parent, entity_type)
	_registered_cells.erase(cell)


func unregister_all() -> void:
	if Engine.is_editor_hint():
		_registered_cells.clear()
		return
	# Ensure we don't later register from the pending queue.
	if (
		WorldGrid != null
		and not _is_tool_placeholder(WorldGrid)
		and WorldGrid.has_method("dequeue_occupant_registration")
	):
		WorldGrid.dequeue_occupant_registration(self)

	var parent = get_parent()
	if not parent:
		_registered_cells.clear()
		return
	# If WorldGrid isn't bound yet, nothing is registered in OccupancyGrid anyway.
	if (
		WorldGrid == null
		or _is_tool_placeholder(WorldGrid)
		or WorldGrid.occupancy == null
		or not WorldGrid.occupancy.ensure_initialized()
	):
		_registered_cells.clear()
		return
	for cell in _registered_cells:
		WorldGrid.unregister_entity(cell, parent, entity_type)
	_registered_cells.clear()


func get_registered_cells() -> Array[Vector2i]:
	return _registered_cells
