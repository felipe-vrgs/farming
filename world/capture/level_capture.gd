class_name LevelCapture
extends Object

const _TERRAIN_CAPTURE := preload("res://world/capture/terrain_capture.gd")
const _ENTITY_CAPTURE := preload("res://world/capture/entity_capture.gd")

static func capture(grid_state: Node, level_id: StringName, player_pos: Vector2) -> LevelSave:
	if grid_state == null or not grid_state.has_method("ensure_initialized"):
		return null
	if not grid_state.ensure_initialized():
		return null

	var ls := LevelSave.new()
	ls.version = 1
	ls.level_id = level_id
	ls.player_pos = player_pos
	ls.cells = _TERRAIN_CAPTURE.capture_cells(grid_state)
	ls.entities = _ENTITY_CAPTURE.capture_entities(grid_state)
	return ls


