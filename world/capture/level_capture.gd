class_name LevelCapture
extends Object

const _TERRAIN_CAPTURE := preload("res://world/capture/terrain_capture.gd")
const _ENTITY_CAPTURE := preload("res://world/capture/entity_capture.gd")

static func capture(level_root: LevelRoot, grid_state: Node) -> LevelSave:
	if level_root == null:
		return null

	var ls := LevelSave.new()
	ls.version = 1
	ls.level_id = level_root.level_id
	ls.cells = _TERRAIN_CAPTURE.capture_cells(grid_state)
	ls.entities = _ENTITY_CAPTURE.capture_entities(level_root)
	return ls


