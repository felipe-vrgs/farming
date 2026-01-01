extends Node

## SpawnManager - provides spawn point positions from data.
##
## Uses SpawnPointData resources directly. No enum needed.

const _SPAWN_POINTS_DIR := "res://data/spawn_points"

## Cache: resource_path -> SpawnPointData
var _spawn_data_cache: Dictionary = {}

func _ready() -> void:
	_load_spawn_data()

func _load_spawn_data() -> void:
	_spawn_data_cache.clear()
	_scan_directory(_SPAWN_POINTS_DIR)

func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var filename := dir.get_next()
		if filename.is_empty():
			break
		if filename.begins_with("."):
			continue

		var full_path := path + "/" + filename

		if dir.current_is_dir():
			_scan_directory(full_path)
		elif filename.ends_with(".tres"):
			var res := load(full_path)
			if res is SpawnPointData:
				var data := res as SpawnPointData
				if data.is_valid():
					_spawn_data_cache[data.resource_path] = data
	dir.list_dir_end()

## Get spawn point by resource path.
func get_spawn_point(path: String) -> SpawnPointData:
	if path.is_empty():
		return null
	if _spawn_data_cache.has(path):
		return _spawn_data_cache[path] as SpawnPointData
	# Try loading directly
	var res := load(path)
	if res is SpawnPointData:
		_spawn_data_cache[path] = res
		return res as SpawnPointData
	return null

## Get spawn position from a SpawnPointData resource.
func get_spawn_pos(spawn_point: SpawnPointData) -> Vector2:
	if spawn_point == null or not spawn_point.is_valid():
		return Vector2.ZERO
	return spawn_point.position

## Get spawn position by resource path.
func get_spawn_pos_by_path(path: String) -> Vector2:
	var sp := get_spawn_point(path)
	return sp.position if sp != null else Vector2.ZERO

## Spawn an actor at a spawn point.
func spawn_actor(scene: PackedScene, level_root: LevelRoot, spawn_point: SpawnPointData) -> Node2D:
	if scene == null or level_root == null:
		return null

	var node := scene.instantiate()
	if not (node is Node2D):
		node.queue_free()
		return null

	node.global_position = get_spawn_pos(spawn_point)
	level_root.get_entities_root().add_child(node)
	return node as Node2D

## Move an existing actor to a spawn point.
func move_actor_to_spawn(actor: Node2D, spawn_point: SpawnPointData) -> bool:
	if actor == null or spawn_point == null or not spawn_point.is_valid():
		return false

	actor.global_position = spawn_point.position
	return true
