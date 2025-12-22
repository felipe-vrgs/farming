extends Node

signal grid_changed(cell: Vector2i)

const PLANT_SCENE: PackedScene = preload("res://entities/plants/plant.tscn")

var _initialized: bool = false
var _grid_data: Dictionary = {} # Vector2i -> GridCellData
var _plant_cache: Dictionary = {} # StringName -> PlantData
var _plants_root: Node2D

func _ready() -> void:
	# Autoloads can be ready before the main scene is. We initialize lazily.
	set_process(false)
	ensure_initialized()
	if TimeManager:
		TimeManager.day_started.connect(_on_day_started)

func _on_day_started(_day_index: int) -> void:
	for cell in _grid_data:
		var data: GridCellData = _grid_data[cell]
		data.advance_day()
		_apply_cell_visuals(cell, data)

func clear_cell(cell: Vector2i, cell_data: GridCellData) -> void:
	if not ensure_initialized():
		# Still clear logical state to avoid leaving stale runtime data around.
		cell_data.clear_soil()
		set_cell_data(cell, cell_data)
		return

	# Visuals are owned by TileMapManager.
	TileMapManager.set_soil_overlay(cell, false)
	TileMapManager.set_wet_overlay(cell, false)
	TileMapManager.set_ground_terrain(cell, GridCellData.TerrainType.DIRT)
	cell_data.clear_soil()
	set_cell_data(cell, cell_data)

func set_cell_data(cell: Vector2i, data: GridCellData) -> void:
	_grid_data[cell] = data
	_sync_runtime_nodes_for_cell(cell, data)
	grid_changed.emit(cell)

func ensure_initialized() -> bool:
	if _initialized:
		return true

	if not TileMapManager.ensure_initialized():
		return false

	var scene := get_tree().current_scene
	if scene == null:
		return false
	_plants_root = _get_or_create_plants_root(scene)
	_initialized = true

	return _initialized

func get_or_create_cell_data(cell: Vector2i) -> GridCellData:
	if _grid_data.has(cell):
		return _grid_data[cell]

	var data = GridCellData.new()
	data.coords = cell

	# Autoload safety: if the main scene isn't ready yet, we can't inspect TileMapLayers.
	# Return a default-initialized data object and let callers retry later.
	if not ensure_initialized():
		_grid_data[cell] = data
		return data

	data = TileMapManager.bootstrap_tile(cell)
	_grid_data[cell] = data
	_sync_runtime_nodes_for_cell(cell, data)
	return data

func set_soil(cell: Vector2i) -> bool:
	if not ensure_initialized():
		return false

	var data := get_or_create_cell_data(cell)
	if data.is_soil():
		return false

	# Update model
	data.terrain_id = GridCellData.TerrainType.SOIL
	data.is_wet = false
	set_cell_data(cell, data)

	# Visuals are owned by SoilGridState
	_apply_cell_visuals(cell, data)
	return true

## Plant a seed at the given cell. Returns true if successful.
func plant_seed(cell: Vector2i, plant_id: StringName) -> bool:
	if not ensure_initialized():
		return false

	var data := get_or_create_cell_data(cell)

	# Must be soil to plant
	if not data.is_soil():
		return false

	# Cannot plant if something is already there
	if data.has_plant():
		return false

	# Verify plant data exists
	if get_plant_data(plant_id) == null:
		push_warning("Attempted to plant invalid plant_id: %s" % plant_id)
		return false

	# Update model
	data.plant_id = plant_id
	data.growth_stage = 0
	data.days_grown = 0
	set_cell_data(cell, data)

	# Visuals are synced automatically by set_cell_data calling _sync_runtime_nodes_for_cell
	return true

## Set wetness for a soil cell. Returns true if it changed the world.
func set_wet(cell: Vector2i, wet: bool) -> bool:
	if not ensure_initialized():
		return false

	var data := get_or_create_cell_data(cell)
	if not data.is_soil():
		return false

	if data.is_wet == wet:
		return false

	data.is_wet = wet
	data.terrain_id = GridCellData.TerrainType.SOIL_WET if wet else GridCellData.TerrainType.SOIL
	set_cell_data(cell, data)
	_apply_cell_visuals(cell, data)
	return true

func get_plant_data(plant_id: StringName) -> PlantData:
	if String(plant_id).is_empty():
		return null
	if _plant_cache.has(plant_id):
		return _plant_cache[plant_id]
	var res: Variant = load(String(plant_id))
	if res is PlantData:
		_plant_cache[plant_id] = res
		return res
	return null

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

func _get_or_create_plants_root(scene: Node) -> Node2D:
	var ground_maps := scene.get_node_or_null(NodePath("GroundMaps"))
	var parent: Node = ground_maps if ground_maps != null else scene

	var existing := parent.get_node_or_null(NodePath("Plants"))
	if existing is Node2D:
		return existing

	var n := Node2D.new()
	n.name = "Plants"
	n.y_sort_enabled = true
	parent.add_child(n)
	return n

func has_valid_neighbors(cell: Vector2i) -> bool:
	if not ensure_initialized():
		return false
	return TileMapManager.has_valid_ground_neighbors(cell)

func _sync_runtime_nodes_for_cell(cell: Vector2i, data: GridCellData) -> void:
	if not ensure_initialized():
		return

	# Plant nodes exist only when there is a plant to render.
	var needs_plant := data != null and not String(data.plant_id).is_empty()
	if not needs_plant:
		if data != null and data.plant_node != null:
			data.plant_node.queue_free()
			data.plant_node = null
		return

	if data.plant_node == null:
		var plant := PLANT_SCENE.instantiate() as Plant
		if plant == null:
			return
		if _plants_root == null:
			_plants_root = _get_or_create_plants_root(get_tree().current_scene)
			if _plants_root == null:
				return
		_plants_root.add_child(plant)
		plant.z_index = 5 # Ensure it's above soil layers
		plant.y_sort_enabled = true
		# map_to_local (called via cell_to_global) returns the center of the tile.
		plant.global_position = TileMapManager.cell_to_global(cell)
		plant.setup(cell)
		data.plant_node = plant
	else:
		data.plant_node.global_position = TileMapManager.cell_to_global(cell)
		data.plant_node.refresh()

func _apply_cell_visuals(cell: Vector2i, data: GridCellData) -> void:
	if not ensure_initialized():
		return
	TileMapManager.apply_cell_visuals(cell, data)
