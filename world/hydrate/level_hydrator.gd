class_name LevelHydrator
extends Object

const _TERRAIN_HYDRATOR := preload("res://world/hydrate/terrain_hydrator.gd")
const _ENTITY_HYDRATOR := preload("res://world/hydrate/entity_hydrator.gd")

static func hydrate(grid_state: Node, level_root: LevelRoot, level_save: LevelSave) -> bool:
	if grid_state == null or level_root == null or level_save == null:
		return false
	if not grid_state.has_method("ensure_initialized"):
		return false
	if not grid_state.ensure_initialized():
		return false

	_ENTITY_HYDRATOR.clear_dynamic_entities(level_root)
	grid_state._grid_data.clear()

	_TERRAIN_HYDRATOR.hydrate_cells_and_apply_tilemap(grid_state, level_save.cells)
	return _ENTITY_HYDRATOR.hydrate_entities(level_root, level_save.entities)


