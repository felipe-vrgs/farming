extends Node

## Centralized manager for grid state and entity lifecycle.
const PLANT_SCENE: PackedScene = preload("res://entities/plants/plant.tscn")

const SOIL_GRID_ENTITY = preload("res://entities/grid/soil_grid_entity.gd")

const WORLD_ENTITY_Z_INDEX := 10

var _initialized: bool = false
var _grid_data: Dictionary = {} # Vector2i -> GridCellData
var _plant_cache: Dictionary = {} # StringName -> PlantData
var _plants_root: Node2D
var _scene_instance_id: int = 0
var _is_farm_level: bool = false

var _soil_entity: Node

# region Lifecycle & Initialization
func _ready() -> void:
	_soil_entity = SOIL_GRID_ENTITY.new()
	add_child(_soil_entity)

	set_process(false)
	ensure_initialized()
	if EventBus:
		EventBus.day_started.connect(_on_day_started)

func ensure_initialized() -> bool:
	# If the current scene changed, drop cached scene references.
	var current := get_tree().current_scene
	var current_id := current.get_instance_id() if current != null else 0
	if _initialized and current_id != _scene_instance_id:
		_initialized = false
		_plants_root = null
		# Grid state is active-level scoped; never leak across levels.
		_grid_data.clear()

	if _initialized:
		return true


	if not TileMapManager.ensure_initialized():
		return false

	var scene := get_tree().current_scene
	if scene == null:
		return false

	_is_farm_level = scene is FarmLevelRoot
	# Prefer enabling grid state for all LevelRoot scenes (farm + non-farm).
	# Saving is decoupled from this, but runtime occupancy/tool queries rely on it.
	if not scene is LevelRoot:
		return false

	# Only farm scenes need a Plants root (seed planting / growth visuals).
	# Non-farm levels still benefit from the occupancy registry for tools/NPC blocking.
	_plants_root = _get_or_create_plants_root(scene) if _is_farm_level else null

	_initialized = true
	_scene_instance_id = scene.get_instance_id()
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
		if plant_entity and plant_entity is Plant:
			plant_entity.on_day_passed(is_wet)

		# Apply soil decay rules
		var old_t := int(data.terrain_id)
		var new_t := SimulationRules.predict_soil_decay(old_t)

		if old_t != new_t:
			data.terrain_id = new_t as GridCellData.TerrainType

			# Batch terrain updates
			if not terrain_groups.has(old_t):
				terrain_groups[old_t] = { "from": old_t, "to": new_t, "cells": [] as Array[Vector2i] }

			(terrain_groups[old_t]["cells"] as Array[Vector2i]).append(cell)

	for key in terrain_groups:
		var g = terrain_groups[key]
		EventBus.terrain_changed.emit(g["cells"], g["from"], g["to"])

# region Public State Mutators

func set_soil(cell: Vector2i) -> bool:
	if not ensure_initialized(): return false
	if not _is_farm_level: return false
	var data := get_or_create_cell_data(cell)
	if data.is_soil(): return false

	var from_terrain := data.terrain_id
	data.terrain_id = GridCellData.TerrainType.SOIL

	_grid_data[cell] = data
	_emit_terrain_changed(cell, from_terrain, data.terrain_id)
	return true

func set_wet(cell: Vector2i) -> bool:
	if not ensure_initialized(): return false
	if not _is_farm_level: return false
	var data := get_or_create_cell_data(cell)
	if not data.is_soil() or data.is_wet(): return false
	var from_terrain := data.terrain_id
	data.terrain_id = GridCellData.TerrainType.SOIL_WET
	_grid_data[cell] = data
	_emit_terrain_changed(cell, from_terrain, GridCellData.TerrainType.SOIL_WET)
	return true

func plant_seed(cell: Vector2i, plant_id: StringName) -> bool:
	if not ensure_initialized(): return false
	if not _is_farm_level: return false
	var data := get_or_create_cell_data(cell)
	if data.is_grass() or data.has_plant() or data.has_obstacle(): return false
	if not data.is_soil():
		set_soil(cell)
	var plant_data = get_plant_data(plant_id)
	if plant_data == null:
		push_warning("Attempted to plant invalid plant_id: %s" % plant_id)
		return false
	_grid_data[cell] = data
	_spawn_plant(cell, plant_id)
	return true

func clear_cell(cell: Vector2i) -> void:
	if not ensure_initialized(): return
	if not _is_farm_level: return
	var data = GridState.get_or_create_cell_data(cell)
	if data.has_obstacle():
		return
	var from_terrain: int = data.terrain_id
	data.terrain_id = GridCellData.TerrainType.DIRT
	var plant_entity = data.get_entity_of_type(Enums.EntityType.PLANT)
	if plant_entity and plant_entity is Plant:
		data.remove_entity(plant_entity, Enums.EntityType.PLANT)
		plant_entity.queue_free()
	_grid_data[cell] = data
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

func get_entities_at(cell: Vector2i) -> Array[Node]:
	if not _grid_data.has(cell):
		return [_soil_entity]

	var entities: Array[Node] = []
	var data = _grid_data[cell]
	for entity in data.entities.values():
		entities.append(entity)
		if data.obstacles.get(data.entities.find_key(entity), false):
			return entities

	entities.append(_soil_entity)
	return entities

# Debug helpers (kept minimal; avoids external code reaching into internals directly).
func debug_get_grid_data() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	return _grid_data

# endregion

# region Internal Entity Management

func register_entity(cell: Vector2i, entity: Node, type: Enums.EntityType) -> void:
	get_or_create_cell_data(cell).add_entity(entity, type)

func unregister_entity(cell: Vector2i, entity: Node, type: Enums.EntityType) -> void:
	if _grid_data.has(cell):
		_grid_data[cell].remove_entity(entity, type)

# endregion

func _spawn_plant(cell: Vector2i, plant_id: StringName) -> void:
	var plant := PLANT_SCENE.instantiate() as Plant
	plant.global_position = TileMapManager.cell_to_global(cell)
	plant.data = get_plant_data(plant_id)
	plant.days_grown = 0
	_plants_root.add_child(plant)

func _emit_terrain_changed(cell: Vector2i, from_t: int, to_t: int) -> void:
	if from_t == to_t: return
	var cells: Array[Vector2i] = [cell]
	EventBus.terrain_changed.emit(cells, from_t, to_t)

func _get_or_create_plants_root(scene: Node) -> Node2D:
	if scene is FarmLevelRoot:
		return scene.get_or_create_plants_root()
	# Non-farm LevelRoot: fall back to the "GroundMaps/Plants" convention or create it.

	var ground_maps := scene.get_node_or_null(NodePath("GroundMaps"))
	var parent: Node = ground_maps if ground_maps != null else scene
	var existing := parent.get_node_or_null(NodePath("Plants"))
	if existing is Node2D: return existing
	var n := Node2D.new()
	n.name = "Plants"
	n.y_sort_enabled = true
	n.z_index = WORLD_ENTITY_Z_INDEX
	parent.add_child(n)
	return n

# endregion
