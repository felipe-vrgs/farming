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
	ensure_initialized()

func ensure_initialized() -> bool:
	# If the current scene changed, drop cached state (active-level scoped).
	var current := get_tree().current_scene
	var current_id := current.get_instance_id() if current != null else 0
	if _initialized and current_id != _scene_instance_id:
		_initialized = false
		_cells.clear()

	if _initialized:
		return true

	var scene := get_tree().current_scene
	if scene == null:
		return false

	# Prefer enabling occupancy for all LevelRoot scenes (farm + non-farm).
	if not (scene is LevelRoot):
		return false

	_initialized = true
	_scene_instance_id = scene.get_instance_id()
	return true

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

func get_entities_at(cell: Vector2i) -> Array[Node]:
	var out: Array[Node] = []
	var data: CellOccupancyData = _cells.get(cell)
	if data == null:
		return out

	for entity in data.entities.values():
		out.append(entity)
		var t = data.entities.find_key(entity)
		if t != null and data.obstacles.get(t, false):
			return out

	return out

func get_entity_of_type(cell: Vector2i, type: Enums.EntityType) -> Node:
	var data: CellOccupancyData = _cells.get(cell)
	if data == null:
		return null
	return data.get_entity_of_type(type)

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


