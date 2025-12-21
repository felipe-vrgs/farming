extends Node

signal grid_changed(cell: Vector2i)

# Terrain IDs (from `tiles/exterior.tres`, terrain_set_0):
const TERRAIN_SET_ID := 0

const SOIL_SCENE: PackedScene = preload("res://entities/soil/soil.tscn")

var _initialized: bool = false
var _ground_layer: TileMapLayer
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
	var wet := scene.get_node_or_null(NodePath("GroundMaps/GroundWetOverlay"))
	if wet is TileMapLayer:
		_wet_overlay_layer = wet as TileMapLayer
	_soils_root = _get_or_create_soils_root(scene)
	_bootstrap_soils_from_ground()
	_initialized = true
	return true

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
	# Hoeing: Dirt -> Soil (spawns Soil node; Soil.setup updates tile visuals)
	var cell_data = _get_or_create_cell_data(cell)

	if cell_data.terrain_id != GridCellData.TerrainType.DIRT:
		return false

	if _spawn_soil(cell) != null:
		cell_data.terrain_id = GridCellData.TerrainType.SOIL
		grid_changed.emit(cell)
		return true
	return false

func _try_water_cell(cell: Vector2i) -> bool:
	# Watering requires a Soil node (gameplay state). If missing, try to bootstrap it.
	var cell_data = _get_or_create_cell_data(cell)
	var soil := _get_soil_at(cell)

	if soil == null and _is_soil(cell_data):
		soil = _spawn_soil(cell)

	if soil == null:
		return false

	soil.water()
	cell_data.is_wet = true
	grid_changed.emit(cell)
	return true

func _is_soil(cell_data: GridCellData) -> bool:
	if cell_data.terrain_id == GridCellData.TerrainType.SOIL:
		return true

	return cell_data.terrain_id == GridCellData.TerrainType.SOIL_WET

func _try_shovel_cell(cell: Vector2i) -> bool:
	# Shoveling: Grass -> Dirt
	var cell_data = _get_or_create_cell_data(cell)

	if cell_data.terrain_id != GridCellData.TerrainType.GRASS:
		return false

	_ground_layer.set_cells_terrain_connect([cell], TERRAIN_SET_ID, GridCellData.TerrainType.DIRT)
	cell_data.terrain_id = GridCellData.TerrainType.DIRT
	grid_changed.emit(cell)
	return true

func _spawn_soil(cell: Vector2i) -> Soil:
	var soil := SOIL_SCENE.instantiate() as Soil
	if soil == null:
		return null

	_soils_root.add_child(soil)
	soil.z_index = 5 # between Ground (1) and Walls (10)
	soil.y_sort_enabled = true
	# Sets tile visuals to dry soil + optional wet overlay.
	soil.setup(cell, _ground_layer, _wet_overlay_layer)
	_soil_by_cell[cell] = soil
	return soil

func _get_soil_at(cell: Vector2i) -> Soil:
	var s = _soil_by_cell.get(cell)
	if s == null:
		return null
	return s as Soil

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

func _bootstrap_soils_from_ground() -> void:
	# If the map is already painted with Soil/WetSoil in the editor, spawn matching nodes.
	for cell in _ground_layer.get_used_cells():
		var cell_data = _get_or_create_cell_data(cell)

		# If we already have soil entity, just ensure data is in sync
		if _get_soil_at(cell) != null:
			cell_data.terrain_id = GridCellData.TerrainType.SOIL # Or infer from Soil
			continue

		var td := _ground_layer.get_cell_tile_data(cell)
		if td == null:
			continue

		var terrain_set = td.get("terrain_set")
		var terrain = td.get("terrain")
		if terrain_set == null or terrain == null:
			continue
		if int(terrain_set) != TERRAIN_SET_ID:
			continue

		var t := int(terrain)
		cell_data.terrain_id = t

		if t == GridCellData.TerrainType.SOIL or t == GridCellData.TerrainType.SOIL_WET:
			var soil := _spawn_soil(cell)
			# If using a wet overlay layer, treat existing wet overlay as the source of wetness.
			if soil != null:
				if _wet_overlay_layer != null and _wet_overlay_layer.get_cell_source_id(cell) != -1:
					soil.water()
					cell_data.is_wet = true
				elif t == GridCellData.TerrainType.SOIL_WET:
					# Back-compat: if map has wet soil painted on the ground layer, mark wet.
					soil.water()
					cell_data.is_wet = true

		# Initial grid state loaded
		grid_changed.emit(cell)

func _get_or_create_cell_data(cell: Vector2i) -> GridCellData:
	if _grid_data.has(cell):
		return _grid_data[cell]

	var data = GridCellData.new()
	data.coords = cell

	# Initial populate from tilemap if possible, otherwise default to 0 (Grass)
	if _ground_layer:
		var td := _ground_layer.get_cell_tile_data(cell)
		if td:
			var t = td.get("terrain")
			if t != null:
				data.terrain_id = int(t)

	_grid_data[cell] = data
	return data

func get_cell_data(cell: Vector2i) -> GridCellData:
	return _grid_data.get(cell)
