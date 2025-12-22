extends Node

signal grid_changed(cell: Vector2i)

# Terrain IDs (from `tiles/exterior.tres`, terrain_set_0):
const TERRAIN_SET_ID := 0

const SOIL_SCENE: PackedScene = preload("res://entities/soil/soil.tscn")

var _initialized: bool = false
var _ground_layer: TileMapLayer
var _soil_overlay_layer: TileMapLayer
var _wet_overlay_layer: TileMapLayer
var _soils_root: Node2D
var _grid_data: Dictionary = {} # Vector2i -> GridCellData

func _ready() -> void:
	# Autoloads can be ready before the main scene is. We initialize lazily.
	set_process(false)
	ensure_initialized()

func clear_cell(cell: Vector2i, cell_data: GridCellData) -> void:
	# Clear overlay cells and refresh neighbors so terrain connectivity recomputes.
	if _soil_overlay_layer:
		_clear_cell_and_refresh_neighbors(_soil_overlay_layer, GridCellData.TerrainType.SOIL, cell)
	if _wet_overlay_layer:
		_clear_cell_and_refresh_neighbors(_wet_overlay_layer, GridCellData.TerrainType.SOIL_WET, cell)
	_ground_layer.set_cells_terrain_connect([cell], TERRAIN_SET_ID, GridCellData.TerrainType.DIRT)
	cell_data.clear_soil()
	set_cell_data(cell, cell_data)

func set_cell_data(cell: Vector2i, data: GridCellData) -> void:
	_grid_data[cell] = data
	grid_changed.emit(cell)

func ensure_initialized() -> bool:
	if _initialized:
		return true

	var scene := get_tree().current_scene
	if scene == null:
		return false

	var ground := scene.get_node_or_null(NodePath("GroundMaps/Ground"))
	if not (ground is TileMapLayer):
		return false
	_ground_layer = ground as TileMapLayer

	var soil := scene.get_node_or_null(NodePath("GroundMaps/SoilOverlay"))
	if not (soil is TileMapLayer):
		return false
	_soil_overlay_layer = soil as TileMapLayer

	var wet := scene.get_node_or_null(NodePath("GroundMaps/SoilWetOverlay"))
	if not (wet is TileMapLayer):
		return false
	_wet_overlay_layer = wet as TileMapLayer

	_soils_root = _get_or_create_soils_root(scene)
	_initialized = true

	return _initialized

func get_or_create_cell_data(cell: Vector2i) -> GridCellData:
	if _grid_data.has(cell):
		return _grid_data[cell]

	var data = GridCellData.new()
	data.coords = cell

	# Initial populate from tilemap if possible, otherwise default to 0 (Grass)
	if _soil_overlay_layer.get_cell_source_id(cell) != -1:
		data.terrain_id = GridCellData.TerrainType.SOIL
	else:
		data.terrain_id = _get_terrain_from_layer(_ground_layer, cell)

	if _wet_overlay_layer.get_cell_source_id(cell) != -1:
		data.is_wet = true
		data.terrain_id = GridCellData.TerrainType.SOIL_WET
	_grid_data[cell] = data
	return data

func spawn_soil(cell: Vector2i) -> Soil:
	var soil := SOIL_SCENE.instantiate() as Soil
	if soil == null:
		return null

	_soils_root.add_child(soil)
	soil.z_index = 5 # between Ground (1) and Walls (10)
	soil.y_sort_enabled = true
	# Sets tile visuals to dry soil + optional wet overlay.
	soil.setup(cell, _soil_overlay_layer, _wet_overlay_layer)

	# Store in grid data
	var data = get_or_create_cell_data(cell)
	data.soil_node = soil

	return soil

func _get_or_create_soils_root(scene: Node) -> Node2D:
	var ground_maps := scene.get_node_or_null(NodePath("GroundMaps"))
	var parent: Node = ground_maps if ground_maps != null else scene

	var existing := parent.get_node_or_null(NodePath("Soils"))
	if existing is Node2D:
		return existing

	var n := Node2D.new()
	n.name = "Soils"
	parent.add_child(n)
	return n

func _get_terrain_from_layer(layer: TileMapLayer, cell: Vector2i) -> int:
	var td := layer.get_cell_tile_data(cell)
	if td == null:
		return GridCellData.TerrainType.NONE

	if td.terrain_set != TERRAIN_SET_ID:
		return GridCellData.TerrainType.NONE

	if td.terrain == -1:
		return GridCellData.TerrainType.NONE

	return td.terrain

func _clear_cell_and_refresh_neighbors(layer: TileMapLayer, terrain: int, cell: Vector2i) -> void:
	if layer == null:
		return

	if layer.get_cell_source_id(cell) == -1:
		return

	layer.set_cell(cell, -1)

	# After clearing a cell, refresh nearby cells of the same terrain so edges/corners recompute.
	var cells: Array[Vector2i] = []
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var c := Vector2i(x, y)
			if layer.get_cell_source_id(c) != -1:
				cells.append(c)

	if not cells.is_empty():
		layer.set_cells_terrain_connect(cells, TERRAIN_SET_ID, terrain)

func has_valid_neighbors(cell: Vector2i) -> bool:
	var neighbors = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT
	]
	for n in neighbors:
		if _get_terrain_from_layer(_ground_layer, cell + n) == GridCellData.TerrainType.NONE:
			return false
	return true
