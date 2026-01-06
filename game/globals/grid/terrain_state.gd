class_name TerrainState
extends Node

## Persisted terrain deltas + farm simulation driver.
## - Stores only the terrain changes relative to the authored TileMap (delta-only persistence).
## - Emits render events through EventBus (TileMapManager listens).
## - Does NOT store runtime occupancy (that's handled by OccupancyGrid).

const PLANT_SCENE: PackedScene = preload("res://game/entities/plants/plant.tscn")

const WORLD_ENTITY_Z_INDEX := 10

var _initialized: bool = false
var _scene_instance_id: int = 0
var _is_farm_level: bool = false

## Vector2i -> TerrainCellData (script instances)
var _terrain: Dictionary = {}

## PlantData cache: StringName (res path) -> PlantData
var _plant_cache: Dictionary = {}
var _plants_root: Node2D

## Always-present interactable for "terrain" tools (hoe/water/shovel).
var _soil_entity: Node

# Dependencies
var _tile_map_manager: TileMapManager
var _occupancy_grid: OccupancyGrid


func setup(tile_map_manager: TileMapManager, occupancy_grid: OccupancyGrid) -> void:
	_tile_map_manager = tile_map_manager
	_occupancy_grid = occupancy_grid


func _ready() -> void:
	_soil_entity = SoilInteractable.new()
	add_child(_soil_entity)
	set_process(false)


func ensure_initialized() -> bool:
	# Strict init: Runtime binds the active LevelRoot after scene changes.
	# We only validate that we are still bound to the current scene.
	var current := get_tree().current_scene
	var current_id := current.get_instance_id() if current != null else 0
	if _initialized and current_id != _scene_instance_id:
		unbind()
		return false
	if not _initialized:
		return false
	if _tile_map_manager == null or not _tile_map_manager.ensure_initialized():
		return false
	return true


func bind_level_root(level_root: LevelRoot) -> bool:
	if level_root == null or not is_instance_valid(level_root):
		return false
	if _tile_map_manager == null or not _tile_map_manager.ensure_initialized():
		return false

	# IMPORTANT:
	# TerrainState stores persisted terrain deltas per level. When levels change, WorldGrid
	# re-binds TileMapManager/OccupancyGrid/TerrainState without necessarily calling unbind()
	# first. Ensure we never leak deltas from a previous level into the next level's save.
	_terrain.clear()

	_is_farm_level = level_root is FarmLevelRoot
	_plants_root = _get_or_create_plants_root(level_root) if _is_farm_level else null

	_initialized = true
	var scene := get_tree().current_scene
	_scene_instance_id = scene.get_instance_id() if scene != null else level_root.get_instance_id()
	return true


func unbind() -> void:
	_initialized = false
	_scene_instance_id = 0
	_is_farm_level = false
	_plants_root = null
	_terrain.clear()


func clear_all() -> void:
	_terrain.clear()


func get_soil_interactable() -> Node:
	return _soil_entity


func get_terrain_at(cell: Vector2i) -> GridCellData.TerrainType:
	# Query without creating a delta.
	var data: TerrainCellData = _terrain.get(cell)
	if data != null:
		return data.terrain_id
	if _tile_map_manager != null:
		return _tile_map_manager.get_terrain_at(cell)
	return GridCellData.TerrainType.NONE


func _get_or_create_cell(cell: Vector2i) -> TerrainCellData:
	var existing: TerrainCellData = _terrain.get(cell)
	if existing != null:
		return existing

	var data: TerrainCellData = TerrainCellData.new()
	data.coords = cell
	data.terrain_persist = false
	if _tile_map_manager != null and _tile_map_manager.ensure_initialized():
		data.terrain_id = _tile_map_manager.get_terrain_at(cell)
	else:
		data.terrain_id = GridCellData.TerrainType.NONE

	_terrain[cell] = data
	return data


func get_persisted_terrain_map() -> Dictionary:
	## Returns Vector2i -> int (GridCellData.TerrainType) for persisted deltas only.
	var out: Dictionary = {}
	for cell in _terrain:
		var data: TerrainCellData = _terrain.get(cell)
		if data == null:
			continue
		if not bool(data.terrain_persist):
			continue
		out[cell] = int(data.terrain_id)
	return out


func load_from_cell_snapshots(cells: Array[CellSnapshot]) -> Dictionary:
	## Loads persisted deltas and returns Vector2i -> int terrain map
	## for TileMapManager.restore_save_state.
	_terrain.clear()
	var out: Dictionary = {}
	for cs in cells:
		if cs == null:
			continue
		var data: TerrainCellData = TerrainCellData.new()
		data.coords = cs.coords
		data.terrain_id = int(cs.terrain_id) as GridCellData.TerrainType
		data.terrain_persist = true
		_terrain[data.coords] = data
		out[data.coords] = int(data.terrain_id)
	return out


## Applies a day tick to the ACTIVE runtime terrain (decay) + plants (via occupancy query).
## Called by WorldGrid facade (triggered on `EventBus.day_started`).
func apply_day_started(_day_index: int) -> void:
	if not ensure_initialized():
		return
	if not _is_farm_level:
		return

	# Use EnvironmentSimulator to calculate changes (logic shared with offline simulation).
	var adapter := OnlineEnvironmentAdapter.new(self)
	var result := EnvironmentSimulator.simulate_day(adapter)

	# 1. Apply Plant Growth
	if _occupancy_grid != null:
		for cell in result.plant_changes:
			var new_days: int = result.plant_changes[cell]
			var plant_entity = _occupancy_grid.get_entity_of_type(cell, Enums.EntityType.PLANT)
			if plant_entity is Plant:
				(plant_entity as Plant).apply_simulated_growth(new_days)

	# 2. Apply Soil Decay
	var terrain_groups: Dictionary[int, Dictionary] = {}

	for cell in result.terrain_changes:
		var new_t: int = result.terrain_changes[cell]
		var old_t: int = get_terrain_at(cell)

		var data: TerrainCellData = _get_or_create_cell(cell)
		data.terrain_id = new_t as GridCellData.TerrainType
		data.terrain_persist = true
		_terrain[cell] = data

		# Group updates for signal batching
		if not terrain_groups.has(old_t):
			terrain_groups[old_t] = {}
		if not terrain_groups[old_t].has(new_t):
			var new_list: Array[Vector2i] = []
			terrain_groups[old_t][new_t] = new_list

		(terrain_groups[old_t][new_t] as Array[Vector2i]).append(cell)

	for from_t in terrain_groups:
		for to_t in terrain_groups[from_t]:
			var cells = terrain_groups[from_t][to_t]
			EventBus.terrain_changed.emit(cells as Array[Vector2i], from_t, to_t)


func set_soil(cell: Vector2i) -> bool:
	if not ensure_initialized():
		return false
	if not _is_farm_level:
		return false

	var data: TerrainCellData = _get_or_create_cell(cell)
	if data.is_soil():
		return false
	var from_terrain := int(data.terrain_id)
	data.terrain_id = GridCellData.TerrainType.SOIL
	data.terrain_persist = true
	_terrain[cell] = data
	_emit_terrain_changed(cell, from_terrain, int(data.terrain_id))
	return true


func set_wet(cell: Vector2i) -> bool:
	if not ensure_initialized():
		return false
	if not _is_farm_level:
		return false
	var data: TerrainCellData = _get_or_create_cell(cell)
	if data.is_grass():
		return false
	var from_terrain := int(data.terrain_id)
	data.terrain_id = GridCellData.TerrainType.SOIL_WET
	data.terrain_persist = true
	_terrain[cell] = data
	_emit_terrain_changed(cell, from_terrain, int(GridCellData.TerrainType.SOIL_WET))
	return true


func clear_cell(cell: Vector2i) -> bool:
	if not ensure_initialized():
		return false
	if not _is_farm_level:
		return false

	# Terrain can only be cleared if no obstacle is present.
	if _occupancy_grid != null and _occupancy_grid.has_obstacle_at(cell):
		return false

	var data: TerrainCellData = _get_or_create_cell(cell)
	var from_terrain := int(data.terrain_id)
	data.terrain_id = GridCellData.TerrainType.DIRT
	data.terrain_persist = true
	_terrain[cell] = data

	# If a plant exists, remove it.
	if _occupancy_grid != null:
		var plant_entity := _occupancy_grid.get_entity_of_type(cell, Enums.EntityType.PLANT)
		if plant_entity != null:
			_occupancy_grid.unregister_entity(cell, plant_entity, Enums.EntityType.PLANT)
			if is_instance_valid(plant_entity):
				plant_entity.queue_free()

	_emit_terrain_changed(cell, from_terrain, int(GridCellData.TerrainType.DIRT))
	return true


func plant_seed(cell: Vector2i, plant_id: StringName) -> bool:
	if not ensure_initialized() or not _is_farm_level or _occupancy_grid == null:
		return false

	var data: TerrainCellData = _get_or_create_cell(cell)
	if data.is_grass():
		return false
	if _occupancy_grid.get_entity_of_type(cell, Enums.EntityType.PLANT) != null:
		return false
	if _occupancy_grid.has_obstacle_at(cell):
		return false

	if not data.is_soil():
		set_soil(cell)

	var plant_data := get_plant_data(plant_id)
	if plant_data == null:
		push_warning("Attempted to plant invalid plant_id: %s" % String(plant_id))
		return false

	_spawn_plant(cell, plant_id)
	return true


func get_plant_data(plant_id: StringName) -> PlantData:
	if String(plant_id).is_empty():
		return null
	if _plant_cache.has(plant_id):
		return _plant_cache[plant_id]
	var res = load(String(plant_id))
	if res is PlantData:
		_plant_cache[plant_id] = res
		return res
	return null


func _spawn_plant(cell: Vector2i, plant_id: StringName) -> void:
	if _plants_root == null:
		return
	var plant := PLANT_SCENE.instantiate() as Plant
	plant.global_position = _tile_map_manager.cell_to_global(cell)
	plant.data = get_plant_data(plant_id)
	plant.days_grown = 0
	_plants_root.add_child(plant)


func _emit_terrain_changed(cell: Vector2i, from_t: int, to_t: int) -> void:
	if from_t == to_t:
		return
	var cells: Array[Vector2i] = [cell]
	EventBus.terrain_changed.emit(cells, from_t, to_t)


func _get_or_create_plants_root(scene: Node) -> Node2D:
	if scene is FarmLevelRoot:
		return (scene as FarmLevelRoot).get_or_create_plants_root()

	# Non-farm LevelRoot: fall back to the "GroundMaps/Plants" convention or create it.
	var ground_maps := scene.get_node_or_null(NodePath("GroundMaps"))
	var parent: Node = ground_maps if ground_maps != null else scene
	var existing := parent.get_node_or_null(NodePath("Plants"))
	if existing is Node2D:
		return existing
	var n := Node2D.new()
	n.name = "Plants"
	n.y_sort_enabled = true
	n.z_index = WORLD_ENTITY_Z_INDEX
	parent.add_child(n)
	return n


func debug_get_terrain_cells() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	return _terrain


## Exposes the set of terrain cells that currently have a runtime delta recorded.
## Used by OnlineEnvironmentAdapter; kept as a method so we don't leak `_terrain`.
func list_terrain_cells_for_simulation() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _terrain:
		out.append(c)
	return out
