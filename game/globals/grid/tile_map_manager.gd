class_name TileMapManager
extends Node

## Centralized TileMap access + rendering helpers.
## This is the only place that should write to TileMap layers.

const TERRAIN_SET_ID := 0

var _initialized: bool = false
var _ground_layer: TileMapLayer
var _ground_detail_layer: TileMapLayer
var _soil_overlay_layer: TileMapLayer
var _wet_overlay_layer: TileMapLayer
var _scene_instance_id: int = 0

# Authored baseline for GroundDetail so hydration can restore it deterministically.
# Vector2i -> { source_id: int, atlas: Vector2i, alt: int }
var _ground_detail_baseline: Dictionary = {}

# Cells we've ever modified via `terrain_changed` (used to revert changes on load).
# Vector2i -> true
var _touched_cells: Dictionary = {}
# Original ground terrain for touched cells, captured the first time we touch them.
# Vector2i -> int (GridCellData.TerrainType)
var _original_ground_terrain: Dictionary = {}


func _ready() -> void:
	# Runtime binds the active LevelRoot after scene changes.
	set_process(false)
	if EventBus:
		EventBus.terrain_changed.connect(_on_terrain_changed)


func _on_terrain_changed(cells: Array[Vector2i], from_terrain: int, to_terrain: int) -> void:
	if not ensure_initialized():
		return
	_mark_cells_touched(cells)
	_apply_terrain_batch(cells, from_terrain, to_terrain)


func _apply_terrain_batch(cells: Array[Vector2i], from_terrain: int, to_terrain: int) -> void:
	if cells.is_empty():
		return

	var from_is_soil := (
		from_terrain == GridCellData.TerrainType.SOIL
		or from_terrain == GridCellData.TerrainType.SOIL_WET
	)
	var to_is_soil := (
		to_terrain == GridCellData.TerrainType.SOIL
		or to_terrain == GridCellData.TerrainType.SOIL_WET
	)
	var from_is_wet := from_terrain == GridCellData.TerrainType.SOIL_WET
	var to_is_wet := to_terrain == GridCellData.TerrainType.SOIL_WET

	# Soil overlay is the "soil presence"; wet overlay is only for wet soil.
	if from_is_soil != to_is_soil:
		_set_soil_overlay_cells(cells, to_is_soil)

	if from_is_wet != to_is_wet:
		_set_wet_overlay_cells(cells, to_is_wet)

	# Ground terrain is relevant for non-soil terrains.
	if not to_is_soil and to_terrain != GridCellData.TerrainType.NONE:
		set_ground_terrain_cells(cells, to_terrain)

	# If we are removing grass, remove any ground-detail decorations too.
	if (
		_ground_detail_layer != null
		and from_terrain == GridCellData.TerrainType.GRASS
		and to_terrain != GridCellData.TerrainType.GRASS
	):
		for cell in cells:
			_ground_detail_layer.set_cell(cell, -1)


func ensure_initialized() -> bool:
	# Strict init: Runtime calls `bind_level_root()`. We only validate that we are
	# still bound to the current scene (and auto-unbind if a scene swap happened).
	var current := get_tree().current_scene
	var current_id := current.get_instance_id() if current != null else 0
	if _initialized and current_id != _scene_instance_id:
		unbind()
		return false
	return _initialized


func bind_level_root(level_root: LevelRoot) -> bool:
	if level_root == null or not is_instance_valid(level_root):
		return false

	var ground := level_root.get_ground_layer()
	if ground == null:
		return false

	_ground_layer = ground
	_ground_detail_layer = null
	_soil_overlay_layer = null
	_wet_overlay_layer = null
	_ground_detail_baseline.clear()

	if level_root is FarmLevelRoot:
		var flr := level_root as FarmLevelRoot
		_soil_overlay_layer = flr.get_soil_overlay_layer()
		_wet_overlay_layer = flr.get_wet_overlay_layer()
		_ground_detail_layer = flr.get_ground_detail_layer()
		_capture_ground_detail_baseline()

	_initialized = true
	var scene := get_tree().current_scene
	_scene_instance_id = scene.get_instance_id() if scene != null else level_root.get_instance_id()
	_touched_cells.clear()
	_original_ground_terrain.clear()
	return true


func unbind() -> void:
	_initialized = false
	_scene_instance_id = 0
	_ground_layer = null
	_ground_detail_layer = null
	_soil_overlay_layer = null
	_wet_overlay_layer = null
	_touched_cells.clear()
	_original_ground_terrain.clear()
	_ground_detail_baseline.clear()


func restore_save_state(cells_data: Dictionary) -> void:
	if not ensure_initialized():
		return
	# Defensive: ensure_initialized() implies these should exist, but avoid hard crashes
	# if a level was bound without expected layers.
	if _ground_layer == null:
		return

	# 0) Revert any cells changed since boot back to their original ground terrain.
	# This fixes: save -> modify ground (grass->dirt) -> load -> visuals not reverting.
	var reset_groups: Dictionary = {}  # int -> Array[Vector2i]
	for cell in _touched_cells:
		var orig: int = int(_original_ground_terrain.get(cell, int(GridCellData.TerrainType.GRASS)))
		if not reset_groups.has(orig):
			reset_groups[orig] = [] as Array[Vector2i]
		(reset_groups[orig] as Array[Vector2i]).append(cell)

	for t in reset_groups:
		_ground_layer.set_cells_terrain_connect(reset_groups[t], TERRAIN_SET_ID, int(t))

	# 1) Clear overlays (we repaint from save).
	if _soil_overlay_layer != null:
		_soil_overlay_layer.clear()
	if _wet_overlay_layer != null:
		_wet_overlay_layer.clear()

	# 1b) Restore GroundDetail baseline, then clear detail on any non-grass saved cells.
	_restore_ground_detail_baseline()
	if _ground_detail_layer != null:
		for cell in cells_data:
			var terrain: int = int(cells_data[cell])
			if terrain != int(GridCellData.TerrainType.GRASS):
				_ground_detail_layer.set_cell(cell, -1)

	# 2) Re-paint cells from save
	var soil_cells: Array[Vector2i] = []
	var wet_cells: Array[Vector2i] = []
	var ground_paint_groups: Dictionary = {}  # int -> Array[Vector2i]

	for cell in cells_data:
		var terrain = cells_data[cell]

		# If it's soil/wet, add to overlay lists
		if terrain == GridCellData.TerrainType.SOIL:
			soil_cells.append(cell)
		elif terrain == GridCellData.TerrainType.SOIL_WET:
			wet_cells.append(cell)  # Wet also needs soil underneath usually, or just wet overlay?
			# In _apply_terrain_batch, we set BOTH if it's wet.
			soil_cells.append(cell)

		# Ground paint: any non-soil terrain in the save should be painted to the ground layer.
		var is_soil = (
			terrain == GridCellData.TerrainType.SOIL or terrain == GridCellData.TerrainType.SOIL_WET
		)
		if not is_soil and terrain != GridCellData.TerrainType.NONE:
			var t_int := int(terrain)
			if not ground_paint_groups.has(t_int):
				ground_paint_groups[t_int] = [] as Array[Vector2i]
			(ground_paint_groups[t_int] as Array[Vector2i]).append(cell)

	if not soil_cells.is_empty():
		# Match gameplay flow: Shovel turns GRASS -> DIRT, then Seeds/Water overlay SOIL on top.
		# Soil edges can reveal the ground underneath, so ensure the base ground is DIRT.
		_ground_layer.set_cells_terrain_connect(
			soil_cells, TERRAIN_SET_ID, GridCellData.TerrainType.DIRT
		)
		_soil_overlay_layer.set_cells_terrain_connect(
			soil_cells, TERRAIN_SET_ID, GridCellData.TerrainType.SOIL
		)

	if not wet_cells.is_empty():
		_wet_overlay_layer.set_cells_terrain_connect(
			wet_cells, TERRAIN_SET_ID, GridCellData.TerrainType.SOIL_WET
		)

	for t in ground_paint_groups:
		_ground_layer.set_cells_terrain_connect(ground_paint_groups[t], TERRAIN_SET_ID, int(t))

	# 3) Reset tracking so post-load edits start tracking from loaded world state.
	_touched_cells.clear()
	_original_ground_terrain.clear()


func bootstrap_tile(cell: Vector2i) -> GridCellData:
	var data := GridCellData.new()
	data.coords = cell

	# Initial populate from tilemap if possible, otherwise default to 0 (Grass)
	if has_soil_overlay(cell):
		data.terrain_id = GridCellData.TerrainType.SOIL
	else:
		data.terrain_id = _get_ground_terrain(cell)

	if _has_wet_overlay(cell):
		data.terrain_id = GridCellData.TerrainType.SOIL_WET
	return data


func has_soil_overlay(cell: Vector2i) -> bool:
	if not ensure_initialized():
		return false
	return _soil_overlay_layer != null and _soil_overlay_layer.get_cell_source_id(cell) != -1


func _has_wet_overlay(cell: Vector2i) -> bool:
	if not ensure_initialized():
		return false
	return _wet_overlay_layer != null and _wet_overlay_layer.get_cell_source_id(cell) != -1


func _get_ground_terrain(cell: Vector2i) -> GridCellData.TerrainType:
	if not ensure_initialized():
		return GridCellData.TerrainType.NONE
	return _get_terrain_from_layer(_ground_layer, cell)


func has_valid_ground_neighbors(cell: Vector2i) -> bool:
	if not ensure_initialized():
		return false
	var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for n in neighbors:
		if _get_terrain_from_layer(_ground_layer, cell + n) == GridCellData.TerrainType.NONE:
			return false
	return true


func cell_to_global(cell: Vector2i) -> Vector2:
	if not ensure_initialized():
		return Vector2.ZERO
	var layer := _soil_overlay_layer if _soil_overlay_layer != null else _ground_layer
	var p_local := layer.map_to_local(cell)
	return layer.to_global(p_local)


func global_to_cell(global_pos: Vector2) -> Vector2i:
	if not ensure_initialized():
		return Vector2i.ZERO
	var layer := _soil_overlay_layer if _soil_overlay_layer != null else _ground_layer
	var local_pos := layer.to_local(global_pos)
	return layer.local_to_map(local_pos)


func get_terrain_at(cell: Vector2i) -> GridCellData.TerrainType:
	if not ensure_initialized():
		return GridCellData.TerrainType.NONE

	# Check for soil overlays first as they override ground
	if _has_wet_overlay(cell):
		return GridCellData.TerrainType.SOIL_WET
	if has_soil_overlay(cell):
		return GridCellData.TerrainType.SOIL

	return _get_ground_terrain(cell)


func set_ground_terrain_cells(cells: Array[Vector2i], terrain: int) -> void:
	if not ensure_initialized():
		return
	if _ground_layer and not cells.is_empty():
		_mark_cells_touched(cells)
		_ground_layer.set_cells_terrain_connect(cells, TERRAIN_SET_ID, terrain)


func _set_soil_overlay_cells(cells: Array[Vector2i], enabled: bool) -> void:
	if not ensure_initialized() or _soil_overlay_layer == null or cells.is_empty():
		return
	_mark_cells_touched(cells)
	if enabled:
		_soil_overlay_layer.set_cells_terrain_connect(
			cells, TERRAIN_SET_ID, GridCellData.TerrainType.SOIL
		)
		_refresh_neighbors_for_many(_soil_overlay_layer, GridCellData.TerrainType.SOIL, cells)
	else:
		for cell in cells:
			_soil_overlay_layer.set_cell(cell, -1)
		_refresh_neighbors_for_many(_soil_overlay_layer, GridCellData.TerrainType.SOIL, cells)


func _set_wet_overlay_cells(cells: Array[Vector2i], enabled: bool) -> void:
	if not ensure_initialized() or _wet_overlay_layer == null or cells.is_empty():
		return
	_mark_cells_touched(cells)
	if enabled:
		_wet_overlay_layer.set_cells_terrain_connect(
			cells, TERRAIN_SET_ID, GridCellData.TerrainType.SOIL_WET
		)
		_refresh_neighbors_for_many(_wet_overlay_layer, GridCellData.TerrainType.SOIL_WET, cells)
	else:
		for cell in cells:
			_wet_overlay_layer.set_cell(cell, -1)
		_refresh_neighbors_for_many(_wet_overlay_layer, GridCellData.TerrainType.SOIL_WET, cells)


func _refresh_neighbors_for_many(layer: TileMapLayer, terrain: int, cells: Array[Vector2i]) -> void:
	if layer == null or cells.is_empty():
		return
	var affected: Array[Vector2i] = []
	var seen := {}
	for cell in cells:
		for y in range(cell.y - 1, cell.y + 2):
			for x in range(cell.x - 1, cell.x + 2):
				var c := Vector2i(x, y)
				if seen.has(c):
					continue
				seen[c] = true
				if layer.get_cell_source_id(c) != -1:
					affected.append(c)
	if not affected.is_empty():
		layer.set_cells_terrain_connect(affected, TERRAIN_SET_ID, terrain)


func _get_terrain_from_layer(layer: TileMapLayer, cell: Vector2i) -> GridCellData.TerrainType:
	if layer == null:
		return GridCellData.TerrainType.NONE
	var td := layer.get_cell_tile_data(cell)
	if td == null:
		return GridCellData.TerrainType.NONE
	if td.terrain_set != TERRAIN_SET_ID:
		return GridCellData.TerrainType.NONE
	if td.terrain == -1:
		return GridCellData.TerrainType.NONE
	return td.terrain as GridCellData.TerrainType


func _mark_cells_touched(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	if not ensure_initialized():
		return
	for cell in cells:
		if not _touched_cells.has(cell):
			_touched_cells[cell] = true
		if not _original_ground_terrain.has(cell):
			_original_ground_terrain[cell] = int(_get_ground_terrain(cell))


func _capture_ground_detail_baseline() -> void:
	_ground_detail_baseline.clear()
	if _ground_detail_layer == null:
		return
	for cell in _ground_detail_layer.get_used_cells():
		var sid: int = _ground_detail_layer.get_cell_source_id(cell)
		if sid == -1:
			continue
		_ground_detail_baseline[cell] = {
			"source_id": sid,
			"atlas": _ground_detail_layer.get_cell_atlas_coords(cell),
			"alt": _ground_detail_layer.get_cell_alternative_tile(cell),
		}


func _restore_ground_detail_baseline() -> void:
	if _ground_detail_layer == null:
		return
	_ground_detail_layer.clear()
	for cell in _ground_detail_baseline:
		var d: Dictionary = _ground_detail_baseline[cell]
		var sid: int = int(d.get("source_id", -1))
		if sid == -1:
			continue
		var atlas: Vector2i = d.get("atlas", Vector2i.ZERO)
		var alt: int = int(d.get("alt", 0))
		_ground_detail_layer.set_cell(cell, sid, atlas, alt)
