extends Node

# Terrain IDs (from `tiles/exterior.tres`, terrain_set_0):
const TERRAIN_SET_ID := 0
const TERRAIN_DIRT := 2
const TERRAIN_SOIL := 5
const TERRAIN_SOIL_WET := 6

const SOIL_SCENE: PackedScene = preload("res://entities/soil/soil.tscn")

var _initialized: bool = false
var _ground_layer: TileMapLayer
var _wet_overlay_layer: TileMapLayer
var _soils_root: Node2D
var _soil_by_cell: Dictionary = {} # Vector2i -> Soil

func _ready() -> void:
	# Autoloads can be ready before the main scene is. We initialize lazily.
	set_process(false)

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
	if not ensure_initialized():
		return false

	var soil := _get_soil_at(cell)
	if soil != null:
		# For now: second press just waters it.
		soil.water()
		return true

	var td := _ground_layer.get_cell_tile_data(cell)
	if td == null:
		return false

	var terrain_set = td.get("terrain_set")
	var terrain = td.get("terrain")
	if terrain_set == null or terrain == null:
		return false
	if int(terrain_set) != TERRAIN_SET_ID or int(terrain) != TERRAIN_DIRT:
		return false

	soil = _spawn_soil(cell)
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
		ToolData.ActionKind.AXE:
			# Trees will be handled by a different grid/entity system.
			return false
		_:
			return false

func _try_hoe_cell(cell: Vector2i) -> bool:
	# Hoeing: Dirt -> Soil (spawns Soil node; Soil.setup updates tile visuals)
	var td := _ground_layer.get_cell_tile_data(cell)
	if td == null:
		return false

	var terrain_set = td.get("terrain_set")
	var terrain = td.get("terrain")
	if terrain_set == null or terrain == null:
		return false
	if int(terrain_set) != TERRAIN_SET_ID or int(terrain) != TERRAIN_DIRT:
		return false

	return _spawn_soil(cell) != null

func _try_water_cell(cell: Vector2i) -> bool:
	# Watering requires a Soil node (gameplay state). If missing, try to bootstrap it.
	var soil := _get_soil_at(cell)
	if soil == null:
		var td := _ground_layer.get_cell_tile_data(cell)
		if td == null:
			return false
		var terrain_set = td.get("terrain_set")
		var terrain = td.get("terrain")
		if terrain_set == null or terrain == null:
			return false
		if int(terrain_set) != TERRAIN_SET_ID:
			return false
		var t := int(terrain)
		if t == TERRAIN_SOIL or t == TERRAIN_SOIL_WET:
			soil = _spawn_soil(cell)

	if soil == null:
		return false

	soil.water()
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
		if _get_soil_at(cell) != null:
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
		if t == TERRAIN_SOIL or t == TERRAIN_SOIL_WET:
			var soil := _spawn_soil(cell)
			# If using a wet overlay layer, treat existing wet overlay as the source of wetness.
			if soil != null:
				if _wet_overlay_layer != null and _wet_overlay_layer.get_cell_source_id(cell) != -1:
					soil.water()
				elif t == TERRAIN_SOIL_WET:
					# Back-compat: if map has wet soil painted on the ground layer, mark wet.
					soil.water()
