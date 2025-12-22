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
		data.is_wet = true
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

func set_ground_terrain(cell: Vector2i, terrain: int) -> void:
	if not ensure_initialized():
		return
	if _ground_layer:
		_ground_layer.set_cells_terrain_connect([cell], TERRAIN_SET_ID, terrain)

func set_soil_overlay(cell: Vector2i, enabled: bool) -> void:
	if not ensure_initialized() or _soil_overlay_layer == null:
		return
	if enabled:
		_set_cell_and_refresh_neighbors(_soil_overlay_layer, GridCellData.TerrainType.SOIL, cell)
	else:
		_clear_cell_and_refresh_neighbors(_soil_overlay_layer, GridCellData.TerrainType.SOIL, cell)

func set_wet_overlay(cell: Vector2i, enabled: bool) -> void:
	if not ensure_initialized() or _wet_overlay_layer == null:
		return
	if enabled:
		_set_cell_and_refresh_neighbors(_wet_overlay_layer, GridCellData.TerrainType.SOIL_WET, cell)
	else:
		_clear_cell_and_refresh_neighbors(_wet_overlay_layer, GridCellData.TerrainType.SOIL_WET, cell)

func apply_cell_visuals(cell: Vector2i, data: GridCellData) -> void:
	if not ensure_initialized():
		return
	set_soil_overlay(cell, data.is_soil())
	set_wet_overlay(cell, data.is_soil() and data.is_wet)

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

func _clear_cell_and_refresh_neighbors(layer: TileMapLayer, terrain: int, cell: Vector2i) -> void:
	if layer == null:
		return
	if layer.get_cell_source_id(cell) == -1:
		return
	layer.set_cell(cell, -1)
	_refresh_neighbors(layer, terrain, cell)

func _set_cell_and_refresh_neighbors(layer: TileMapLayer, terrain: int, cell: Vector2i) -> void:
	if layer == null:
		return
	layer.set_cells_terrain_connect([cell], TERRAIN_SET_ID, terrain)
	_refresh_neighbors(layer, terrain, cell)

func _refresh_neighbors(layer: TileMapLayer, terrain: int, cell: Vector2i) -> void:
	var cells: Array[Vector2i] = []
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var c := Vector2i(x, y)
			if layer.get_cell_source_id(c) != -1:
				cells.append(c)
	if not cells.is_empty():
		layer.set_cells_terrain_connect(cells, TERRAIN_SET_ID, terrain)
