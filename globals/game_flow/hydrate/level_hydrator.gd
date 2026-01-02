class_name LevelHydrator
extends Object

static func hydrate(grid_state: Node, level_root: LevelRoot, level_save: LevelSave) -> bool:
	if grid_state == null or level_root == null or level_save == null:
		return false
	if not grid_state.has_method("ensure_initialized"):
		return false
	if not grid_state.ensure_initialized():
		return false

	var t0_ms := Time.get_ticks_msec()
	var cell_count := level_save.cells.size()
	var entity_count := level_save.entities.size()
	if OS.is_debug_build():
		print("Hydrate: start level=%s cells=%d entities=%d" % [
			str(level_save.level_id), cell_count, entity_count
		])

	EntityHydrator.clear_dynamic_entities(level_root)
	# Clear registries (terrain deltas + occupancy).
	if WorldGrid.terrain_state != null:
		WorldGrid.terrain_state.clear_all()
	if WorldGrid.occupancy != null:
		WorldGrid.occupancy.clear_all()

	var t1_ms := Time.get_ticks_msec()
	TerrainHydrator.hydrate_cells_and_apply_tilemap(grid_state, level_save.cells)
	var t2_ms := Time.get_ticks_msec()

	var ok := EntityHydrator.hydrate_entities(level_root, level_save.entities)
	var t3_ms := Time.get_ticks_msec()

	if OS.is_debug_build():
		print("Hydrate: done level=%s ok=%s clear=%dms terrain=%dms entities=%dms total=%dms" % [
			str(level_save.level_id),
			str(ok),
			(t1_ms - t0_ms),
			(t2_ms - t1_ms),
			(t3_ms - t2_ms),
			(t3_ms - t0_ms),
		])

	return ok


