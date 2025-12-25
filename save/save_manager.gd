extends Node

const DEFAULT_SAVE_PATH := "user://savegame.tres"
const _GRID_SERIALIZER := preload("res://save/serializers/grid_serializer.gd")

func save_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	if not GridState:
		return false
	var save: SaveGame = _GRID_SERIALIZER.capture(GridState)
	if save == null:
		return false
	return ResourceSaver.save(save, path) == OK

func load_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var res = ResourceLoader.load(path)
	var save := res as SaveGame
	if save == null:
		return false
	if not GridState:
		return false
	return _GRID_SERIALIZER.restore(GridState, save)


