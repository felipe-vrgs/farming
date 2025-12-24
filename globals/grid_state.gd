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
	return true

func _on_day_started(_day_index: int) -> void:
	var terrain_groups := {}

	for cell in _grid_data:
		var data: GridCellData = _grid_data[cell]
		var from_terrain := data.terrain_id

		# If advance_day returns true, it means either wetness or growth changed.
		if data.advance_day():
			# Sync nodes (this handles plant growth visuals)
			_sync_runtime_nodes_for_cell(cell, data)

			# Group terrain changes for bulk TileMap update
			if data.terrain_id != from_terrain:
				var key := (int(from_terrain) << 16) | (int(data.terrain_id) & 0xFFFF)
				if not terrain_groups.has(key):
					terrain_groups[key] = {
						"from": from_terrain,
						"to": data.terrain_id,
						"cells": [] as Array[Vector2i]
					}
				(terrain_groups[key]["cells"] as Array[Vector2i]).append(cell)

	for key in terrain_groups:
		var g = terrain_groups[key]
		EventBus.terrain_changed.emit(g["cells"], g["from"], g["to"])

# endregion

# region Player Management

func update_player_position(player_pos: Vector2) -> void:
	var new_cell := TileMapManager.global_to_cell(player_pos)
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
	data.is_wet = false

	_set_cell_data(cell, data)
	_emit_terrain_changed(cell, from_terrain, data.terrain_id)
	return true

func set_wet(cell: Vector2i, wet: bool) -> bool:
	if not ensure_initialized(): return false
	var data := get_or_create_cell_data(cell)
	if not data.is_soil() or data.is_wet == wet: return false

	var from_terrain := data.terrain_id
	data.is_wet = wet
	data.terrain_id = GridCellData.TerrainType.SOIL_WET if wet else GridCellData.TerrainType.SOIL

	_set_cell_data(cell, data)
	_emit_terrain_changed(cell, from_terrain, data.terrain_id)
	return true

func plant_seed(cell: Vector2i, plant_id: StringName) -> bool:
	if not ensure_initialized(): return false
	var data := get_or_create_cell_data(cell)
	if not data.is_soil() or data.has_plant() or data.has_obstacle(): return false

	if get_plant_data(plant_id) == null:
		push_warning("Attempted to plant invalid plant_id: %s" % plant_id)
		return false

	data.plant_id = plant_id
	data.growth_stage = 0
	data.days_grown = 0
	_set_cell_data(cell, data)
	return true

func clear_cell(cell: Vector2i, cell_data: GridCellData) -> void:
	var from_terrain := cell_data.terrain_id
	cell_data.clear_soil()
	_set_cell_data(cell, cell_data)

	if ensure_initialized():
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
	_set_cell_data(cell, data)
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

# endregion

# region Internal Entity Management

func register_entity(cell: Vector2i, entity: GridEntity) -> void:
	get_or_create_cell_data(cell).add_occupant(entity)

func unregister_entity(cell: Vector2i, entity: GridEntity) -> void:
	if _grid_data.has(cell):
		_grid_data[cell].remove_occupant(entity)

# endregion

# region Private Helpers

func _set_cell_data(cell: Vector2i, data: GridCellData) -> void:
	_grid_data[cell] = data
	_sync_runtime_nodes_for_cell(cell, data)

func _sync_runtime_nodes_for_cell(cell: Vector2i, data: GridCellData) -> void:
	if not ensure_initialized(): return

	var plant_entity = data.get_entity_of_type(Enums.EntityType.PLANT) as Plant
	var needs_plant := not String(data.plant_id).is_empty()

	# Case 1: Plant cleared or harvested
	if plant_entity and not needs_plant:
		plant_entity.queue_free()
		return

	# Case 2: New plant created
	if not plant_entity and needs_plant:
		var plant := PLANT_SCENE.instantiate() as Plant
		plant.z_index = 5
		plant.y_sort_enabled = true
		plant.global_position = TileMapManager.cell_to_global(cell)
		_plants_root.add_child(plant)
		return

	# Case 3: Update existing plant (growth stage, etc)
	if plant_entity and needs_plant:
		plant_entity.global_position = TileMapManager.cell_to_global(cell)
		plant_entity.refresh()

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
