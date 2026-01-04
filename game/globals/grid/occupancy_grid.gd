class_name OccupancyGrid
extends Node

## Runtime-only grid occupancy registry.
## - Tracks which entities occupy which cells (and which entity types block movement/tools).
## - Rebuilt at runtime by GridOccupantComponent / GridDynamicOccupantComponent.

var _initialized: bool = false
var _scene_instance_id: int = 0

## Vector2i -> CellOccupancyData
var _cells: Dictionary = {}


func _ready() -> void:
	set_process(false)


func ensure_initialized() -> bool:
	# Strict init: Runtime binds the active LevelRoot after scene changes.
	# We only validate that we are still bound to the current scene.
	var current := get_tree().current_scene
	var current_id := current.get_instance_id() if current != null else 0
	if _initialized and current_id != _scene_instance_id:
		unbind()
		return false
	return _initialized


func bind_level_root(level_root: LevelRoot) -> bool:
	if level_root == null or not is_instance_valid(level_root):
		return false
	_initialized = true
	var scene := get_tree().current_scene
	_scene_instance_id = scene.get_instance_id() if scene != null else level_root.get_instance_id()
	_cells.clear()
	return true


func unbind() -> void:
	_initialized = false
	_scene_instance_id = 0
	_cells.clear()


func clear_all() -> void:
	_cells.clear()


func register_entity(cell: Vector2i, entity: Node, type: Enums.EntityType) -> void:
	if not ensure_initialized():
		return
	if entity == null:
		return
	var data: CellOccupancyData = _cells.get(cell)
	if data == null:
		data = CellOccupancyData.new()
		data.coords = cell
		_cells[cell] = data
	data.add_entity(entity, type)


func unregister_entity(cell: Vector2i, entity: Node, type: Enums.EntityType) -> void:
	if not _cells.has(cell):
		return
	var data: CellOccupancyData = _cells.get(cell)
	if data == null:
		_cells.erase(cell)
		return
	data.remove_entity(entity, type)
	if data.entities.is_empty():
		_cells.erase(cell)


func get_entities_at(cell: Vector2i):
	var q: CellInteractionQuery = CellInteractionQuery.new()
	var data: CellOccupancyData = _cells.get(cell)
	if data == null:
		return q

	# If an obstacle exists, we prefer returning just that obstacle entity as the
	# effective "frontmost" target for the cell.
	# (This keeps behavior deterministic and ensures obstacles block terrain.)
	if data.has_obstacle():
		q.has_obstacle = true
		var obstacle_order: Array[Enums.EntityType] = [
			Enums.EntityType.BUILDING,
			Enums.EntityType.ROCK,
			Enums.EntityType.TREE,
			Enums.EntityType.NPC,
		]
		for t in obstacle_order:
			var e := data.get_entity_of_type(t)
			if e != null:
				q.entities.append(e)
				return q

	# No obstacle: return all entities (order is not guaranteed).
	for e in data.entities.values():
		if is_instance_valid(e):
			q.entities.append(e)

	return q


func get_entity_of_type(cell: Vector2i, type: Enums.EntityType) -> Node:
	var data: CellOccupancyData = _cells.get(cell)
	if data == null:
		return null
	var e := data.get_entity_of_type(type)
	if is_instance_valid(e):
		return e
	return null


func has_obstacle_at(cell: Vector2i) -> bool:
	var data: CellOccupancyData = _cells.get(cell)
	return data != null and data.has_obstacle()


func get_cells_with_entity_type(type: Enums.EntityType) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _cells:
		var data: CellOccupancyData = _cells.get(cell)
		if data != null and data.has_entity_type(type):
			out.append(cell)
	return out


func debug_get_cells() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	return _cells
