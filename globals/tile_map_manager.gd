extends Node

## Centralized TileMap access + rendering helpers.
## This is the only place that should write to TileMap layers.

const TERRAIN_SET_ID := 0

var _initialized: bool = false
var _ground_layer: TileMapLayer
var _soil_overlay_layer: TileMapLayer
var _wet_overlay_layer: TileMapLayer

func _ready() -> void:
	# Autoloads can be ready before the main scene is. Initialize lazily.
	set_process(false)
	ensure_initialized()
	if EventBus:
		EventBus.terrain_changed.connect(_on_terrain_changed)

func _on_terrain_changed(cells: Array[Vector2i], from_terrain: int, to_terrain: int) -> void:
	if not ensure_initialized():
		return
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

func ensure_initialized() -> bool:
	if _initialized:
		return true

	var scene := get_tree().current_scene
	if scene == null:
		return false

	var ground := scene.get_node_or_null(NodePath("GroundMaps/Ground"))
	if ground is TileMapLayer:
		_ground_layer = ground as TileMapLayer
	else:
		return false

	var soil := scene.get_node_or_null(NodePath("GroundMaps/SoilOverlay"))
	if soil is TileMapLayer:
		_soil_overlay_layer = soil as TileMapLayer
	else:
		return false

	var wet := scene.get_node_or_null(NodePath("GroundMaps/SoilWetOverlay"))
	if wet is TileMapLayer:
		_wet_overlay_layer = wet as TileMapLayer
	else:
		return false

	_initialized = true
	return true

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
		_ground_layer.set_cells_terrain_connect(cells, TERRAIN_SET_ID, terrain)

func _set_soil_overlay_cells(cells: Array[Vector2i], enabled: bool) -> void:
	if not ensure_initialized() or _soil_overlay_layer == null or cells.is_empty():
		return
	if enabled:
		_soil_overlay_layer.set_cells_terrain_connect(
			cells,
			TERRAIN_SET_ID,
			GridCellData.TerrainType.SOIL
		)
		_refresh_neighbors_for_many(_soil_overlay_layer, GridCellData.TerrainType.SOIL, cells)
	else:
		for cell in cells:
			_soil_overlay_layer.set_cell(cell, -1)
		_refresh_neighbors_for_many(_soil_overlay_layer, GridCellData.TerrainType.SOIL, cells)

func _set_wet_overlay_cells(cells: Array[Vector2i], enabled: bool) -> void:
	if not ensure_initialized() or _wet_overlay_layer == null or cells.is_empty():
		return
	if enabled:
		_wet_overlay_layer.set_cells_terrain_connect(
			cells,
			TERRAIN_SET_ID,
			GridCellData.TerrainType.SOIL_WET
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
