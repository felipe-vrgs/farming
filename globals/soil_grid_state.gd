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
var _soil_by_cell: Dictionary = {} # Vector2i -> Soil
var _grid_data: Dictionary = {} # Vector2i -> GridCellData

func _ready() -> void:
	# Autoloads can be ready before the main scene is. We initialize lazily.
	set_process(false)
	ensure_initialized()

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
	if wet is TileMapLayer:
		_wet_overlay_layer = wet as TileMapLayer

	_soils_root = _get_or_create_soils_root(scene)
	_bootstrap_soils_from_ground()
	_initialized = true
	return true

func _bootstrap_soils_from_ground() -> void:
	# Collect all relevant cells from ground and overlays
	var all_cells: Dictionary = {} # Vector2i -> true (set)

	if _ground_layer:
		for c in _ground_layer.get_used_cells():
			all_cells[c] = true

	if _soil_overlay_layer:
		for c in _soil_overlay_layer.get_used_cells():
			all_cells[c] = true

	if _wet_overlay_layer:
		for c in _wet_overlay_layer.get_used_cells():
			all_cells[c] = true

	# Initialize grid data for all found cells
	for cell in all_cells.keys():
		var cell_data = _get_or_create_cell_data(cell)

		# If we already have soil entity (from legacy or manual spawn), just ensure data is in sync
		if _get_soil_at(cell) != null:
			if _wet_overlay_layer:
				cell_data.is_wet = _wet_overlay_layer.get_cell_source_id(cell) != -1
			continue

		var overlay_has_soil := _soil_overlay_layer and _soil_overlay_layer.get_cell_source_id(cell) != -1
		var overlay_is_wet := _wet_overlay_layer and _wet_overlay_layer.get_cell_source_id(cell) != -1

		if overlay_has_soil:
			var s := _spawn_soil(cell)
			cell_data.terrain_id = GridCellData.TerrainType.SOIL
			cell_data.is_wet = false

			if s != null and overlay_is_wet:
				s.water()
				cell_data.is_wet = true
		else:
			# No soil overlay: the terrain is purely the base ground.
			# _get_or_create_cell_data already handles base terrain,
			# but we ensure consistency here if needed.
			pass

		# Initial grid state loaded
		grid_changed.emit(cell)

func get_cell_data(cell: Vector2i) -> GridCellData:
	return _grid_data.get(cell)

func try_farm_at_cell(cell: Vector2i) -> bool:
	var cell_data = _get_or_create_cell_data(cell)
	var soil := _get_soil_at(cell)

	if soil != null:
		# For now: second press just waters it.
		soil.water()
		cell_data.is_wet = true
		grid_changed.emit(cell)
		return true

	if cell_data.terrain_id != GridCellData.TerrainType.DIRT:
		return false

	soil = _spawn_soil(cell)
	cell_data.terrain_id = GridCellData.TerrainType.SOIL
	grid_changed.emit(cell)
	return soil != null

func try_use_tool(tool: ToolData, cell: Vector2i) -> bool:
	if tool == null:
		return false

	if not ensure_initialized():
		return false

	match tool.action_kind:
		ToolData.ActionKind.HOE:
			return _try_hoe_cell(cell)
		ToolData.ActionKind.WATER:
			return _try_water_cell(cell)
		ToolData.ActionKind.SHOVEL:
			return _try_shovel_cell(cell)
		_:
			return false

func _try_hoe_cell(cell: Vector2i) -> bool:
	# Hoeing: Dirt -> Soil (spawns Soil node; Soil.setup paints SoilOverlay)
	var cell_data = _get_or_create_cell_data(cell)

	# Must be dirt on the base Ground layer.
	var base_t := _get_terrain_from_layer(_ground_layer, cell)
	if base_t != GridCellData.TerrainType.DIRT:
		return false

	# If we already have soil here, nothing to do.
	if _has_soil_at(cell):
		return false

	if _spawn_soil(cell) != null:
		cell_data.terrain_id = GridCellData.TerrainType.SOIL
		cell_data.is_wet = false
		grid_changed.emit(cell)
		return true
	return false

func _try_water_cell(cell: Vector2i) -> bool:
	# Watering requires a Soil node (gameplay state). If missing, try to bootstrap it.
	var cell_data = _get_or_create_cell_data(cell)
	var soil := _get_soil_at(cell)

	if soil == null and _has_soil_at(cell):
		soil = _spawn_soil(cell)

	if soil == null:
		return false

	soil.water()
	cell_data.is_wet = true
	grid_changed.emit(cell)
	return true

func _try_shovel_cell(cell: Vector2i) -> bool:
	# Shoveling:
	# - Grass -> Dirt (base ground)
	# - Soil/WetSoil -> Dirt (clears overlays + soil entity)
	var cell_data = _get_or_create_cell_data(cell)

	var base_t := _get_terrain_from_layer(_ground_layer, cell)
	var has_soil := _has_soil_at(cell) or _get_soil_at(cell) != null

	if not has_soil and base_t != GridCellData.TerrainType.GRASS:
		return false

	# Clear soil entity (if any)
	var soil := _get_soil_at(cell)
	if soil != null:
		soil.queue_free()
		_soil_by_cell.erase(cell)

	# Clear overlay cells and refresh neighbors so terrain connectivity recomputes.
	if _soil_overlay_layer:
		_clear_cell_and_refresh_neighbors(_soil_overlay_layer, GridCellData.TerrainType.SOIL, cell)
	if _wet_overlay_layer:
		_clear_cell_and_refresh_neighbors(_wet_overlay_layer, GridCellData.TerrainType.SOIL_WET, cell)

	_ground_layer.set_cells_terrain_connect([cell], TERRAIN_SET_ID, GridCellData.TerrainType.DIRT)
	cell_data.terrain_id = GridCellData.TerrainType.DIRT
	cell_data.is_wet = false
	grid_changed.emit(cell)
	return true

func _get_or_create_cell_data(cell: Vector2i) -> GridCellData:
	if _grid_data.has(cell):
		return _grid_data[cell]

	var data = GridCellData.new()
	data.coords = cell

	# Initial populate from tilemap if possible, otherwise default to 0 (Grass)
	if _soil_overlay_layer and _soil_overlay_layer.get_cell_source_id(cell) != -1:
		data.terrain_id = GridCellData.TerrainType.SOIL
	elif _ground_layer:
		data.terrain_id = _get_terrain_from_layer(_ground_layer, cell)

	if _wet_overlay_layer and _wet_overlay_layer.get_cell_source_id(cell) != -1:
		data.is_wet = true
		# Wetness is represented as a separate overlay + boolean, keep terrain as SOIL.
		data.terrain_id = GridCellData.TerrainType.SOIL

	_grid_data[cell] = data
	return data

func _spawn_soil(cell: Vector2i) -> Soil:
	var soil := SOIL_SCENE.instantiate() as Soil
	if soil == null:
		return null

	_soils_root.add_child(soil)
	soil.z_index = 5 # between Ground (1) and Walls (10)
	soil.y_sort_enabled = true
	# Sets tile visuals to dry soil + optional wet overlay.
	soil.setup(cell, _soil_overlay_layer, _wet_overlay_layer)
	_soil_by_cell[cell] = soil
	return soil

func _get_soil_at(cell: Vector2i) -> Soil:
	var s = _soil_by_cell.get(cell)
	if s == null:
		return null
	return s as Soil

func _has_soil_at(cell: Vector2i) -> bool:
	if _soil_overlay_layer != null and _soil_overlay_layer.get_cell_source_id(cell) != -1:
		return true
	# Legacy compatibility: a Soil entity means "soil exists", even if overlay is empty.
	return _soil_by_cell.has(cell)

func _is_soil(cell_data: GridCellData) -> bool:
	if cell_data.terrain_id == GridCellData.TerrainType.SOIL:
		return true
	return cell_data.terrain_id == GridCellData.TerrainType.SOIL_WET

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
	if layer == null:
		return GridCellData.TerrainType.GRASS
	var td := layer.get_cell_tile_data(cell)
	if td == null:
		return GridCellData.TerrainType.GRASS
	var terrain_set = td.get("terrain_set")
	var terrain = td.get("terrain")
	if terrain_set == null or terrain == null:
		return GridCellData.TerrainType.GRASS
	if int(terrain_set) != TERRAIN_SET_ID:
		return GridCellData.TerrainType.GRASS
	return int(terrain)

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
