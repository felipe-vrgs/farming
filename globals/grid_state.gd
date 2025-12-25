extends Node

## Centralized manager for grid state and entity lifecycle.
const PLANT_SCENE: PackedScene = preload("res://entities/plants/plant.tscn")

var _initialized: bool = false
var _grid_data: Dictionary = {} # Vector2i -> GridCellData
var _plant_cache: Dictionary = {} # StringName -> PlantData
var _plants_root: Node2D
var _player_cell: Vector2i = Vector2i(-9999, -9999)

# region Lifecycle & Initialization
func _ready() -> void:
	set_process(false)
	ensure_initialized()
	if EventBus:
		EventBus.day_started.connect(_on_day_started)

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
	# TODO: Save and load feature for plants/trees (GridEntity)
	return true

func _on_day_started(_day_index: int) -> void:
	var terrain_groups := {
		GridCellData.TerrainType.SOIL_WET: {
			"from": GridCellData.TerrainType.SOIL_WET,
			"to": GridCellData.TerrainType.SOIL,
			"cells": [] as Array[Vector2i]
		}
	}

	for cell in _grid_data:
		var data: GridCellData = _grid_data[cell]
		var is_wet: bool = data.is_wet()

		var plant_entity = data.get_entity_of_type(Enums.EntityType.PLANT)
		if plant_entity is Plant:
			plant_entity.on_day_passed(is_wet)

		if is_wet:
			data.terrain_id = GridCellData.TerrainType.SOIL
			(terrain_groups[GridCellData.TerrainType.SOIL_WET]["cells"] as Array[Vector2i]).append(cell)

	for key in terrain_groups:
		var g = terrain_groups[key]
		EventBus.terrain_changed.emit(g["cells"], g["from"], g["to"])

# endregion

# region Player Management

func update_player_position(player_pos: Vector2) -> void:
	var new_cell: Vector2i = TileMapManager.global_to_cell(player_pos)
	if _player_cell == new_cell:
		return

	if EventBus and _player_cell != Vector2i(-9999, -9999):
		EventBus.player_moved_to_cell.emit(new_cell, player_pos)
	_player_cell = new_cell

# endregion

# region Public State Mutators

func set_soil(cell: Vector2i) -> bool:
	if not ensure_initialized(): return false
	var data := get_or_create_cell_data(cell)
	if data.is_soil(): return false

	var from_terrain := data.terrain_id
	data.terrain_id = GridCellData.TerrainType.SOIL

	_grid_data[cell] = data
	_emit_terrain_changed(cell, from_terrain, data.terrain_id)
	return true

func set_wet(cell: Vector2i) -> bool:
	if not ensure_initialized(): return false
	var data := get_or_create_cell_data(cell)
	if not data.is_soil() or data.is_wet(): return false
	var from_terrain := data.terrain_id
	data.terrain_id = GridCellData.TerrainType.SOIL_WET
	_grid_data[cell] = data
	_emit_terrain_changed(cell, from_terrain, GridCellData.TerrainType.SOIL_WET)
	return true

func plant_seed(cell: Vector2i, plant_id: StringName) -> bool:
	if not ensure_initialized(): return false
	var data := get_or_create_cell_data(cell)
	if not data.is_soil() or data.has_plant() or data.has_obstacle(): return false
	var plant_data = get_plant_data(plant_id)
	if plant_data == null:
		push_warning("Attempted to plant invalid plant_id: %s" % plant_id)
		return false
	_grid_data[cell] = data
	_spawn_plant(cell, plant_id)
	return true

func clear_cell(cell: Vector2i, cell_data: GridCellData) -> void:
	var from_terrain := cell_data.terrain_id
	cell_data.terrain_id = GridCellData.TerrainType.DIRT
	var plant: Plant = cell_data.get_entity_of_type(Enums.EntityType.PLANT) as Plant
	if plant:
		cell_data.remove_occupant(plant)
		plant.queue_free()
	_grid_data[cell] = cell_data
	_emit_terrain_changed(cell, from_terrain, GridCellData.TerrainType.DIRT)

# endregion

# region Public Getters

func get_or_create_cell_data(cell: Vector2i) -> GridCellData:
	if _grid_data.has(cell): return _grid_data[cell]

	var data = GridCellData.new()
	data.coords = cell
	if not ensure_initialized():
		_grid_data[cell] = data
		return data

	data = TileMapManager.bootstrap_tile(cell)
	_grid_data[cell] = data
	return data

func get_plant_data(plant_id: StringName) -> PlantData:
	if String(plant_id).is_empty(): return null
	if _plant_cache.has(plant_id): return _plant_cache[plant_id]
	var res = load(String(plant_id))
	if res is PlantData:
		_plant_cache[plant_id] = res
		return res
	return null

func get_entity_at(cell: Vector2i, type: Enums.EntityType) -> GridEntity:
	if not _grid_data.has(cell): return null
	return _grid_data[cell].get_entity_of_type(type)

# Debug helpers (kept minimal; avoids external code reaching into internals directly).
func debug_get_grid_data() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	return _grid_data

# endregion

# region Internal Entity Management

func register_entity(cell: Vector2i, entity: GridEntity) -> void:
	get_or_create_cell_data(cell).add_occupant(entity)

func unregister_entity(cell: Vector2i, entity: GridEntity) -> void:
	if _grid_data.has(cell):
		_grid_data[cell].remove_occupant(entity)

# endregion

func _spawn_plant(cell: Vector2i, plant_id: StringName) -> void:
	var plant := PLANT_SCENE.instantiate() as Plant
	plant.z_index = 5
	plant.y_sort_enabled = true
	plant.global_position = TileMapManager.cell_to_global(cell)
	plant.data = get_plant_data(plant_id)
	plant.days_grown = 0
	_plants_root.add_child(plant)

func _emit_terrain_changed(cell: Vector2i, from_t: int, to_t: int) -> void:
	if from_t == to_t: return
	var cells: Array[Vector2i] = [cell]
	EventBus.terrain_changed.emit(cells, from_t, to_t)

func _get_or_create_plants_root(scene: Node) -> Node2D:
	var ground_maps := scene.get_node_or_null(NodePath("GroundMaps"))
	var parent: Node = ground_maps if ground_maps != null else scene
	var existing := parent.get_node_or_null(NodePath("Plants"))
	if existing is Node2D: return existing
	var n := Node2D.new()
	n.name = "Plants"
	n.y_sort_enabled = true
	parent.add_child(n)
	return n

# endregion
