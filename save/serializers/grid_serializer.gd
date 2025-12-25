class_name GridSerializer
extends Object

const _TERRAIN_SERIALIZER := preload("res://save/serializers/terrain_serializer.gd")
const _ENTITY_SERIALIZER := preload("res://save/serializers/entity_serializer.gd")

static func capture(grid_state: Node) -> SaveGame:
	if grid_state == null or not grid_state.has_method("ensure_initialized"):
		return null
	if not grid_state.ensure_initialized():
		return null

	var save := SaveGame.new()
	save.version = 1

	# Time.
	if TimeManager:
		save.current_day = int(TimeManager.current_day)

	save.cells = _TERRAIN_SERIALIZER.capture_cells(grid_state)
	save.entities = _ENTITY_SERIALIZER.capture_entities(grid_state)

	return save

static func restore(grid_state: Node, save: SaveGame) -> bool:
	if grid_state == null or save == null:
		return false
	if not grid_state.has_method("ensure_initialized"):
		return false
	if not grid_state.ensure_initialized():
		return false

	# Apply time first so any day-based systems see the right value.
	if TimeManager:
		TimeManager.current_day = int(save.current_day)

	_ENTITY_SERIALIZER.clear_runtime_entities(grid_state.get_tree())
	_TERRAIN_SERIALIZER.restore_cells_and_apply_tilemap(grid_state, save.cells)
	return _ENTITY_SERIALIZER.restore_entities(grid_state, save.entities)


