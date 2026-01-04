class_name LevelCapture
extends Object


static func capture(level_root: LevelRoot, grid_state: Node) -> LevelSave:
	if level_root == null:
		return null

	var ls := LevelSave.new()
	ls.version = 1
	ls.level_id = level_root.level_id
	ls.cells = TerrainCapture.capture_cells(grid_state)
	ls.entities = EntityCapture.capture_entities(level_root)
	return ls
