extends Node

const DEFAULT_SAVE_PATH := "user://savegame.tres"
const _GRID_SERIALIZER := preload("res://save/serializers/grid_serializer.gd")
const _LOADING_SCREEN_SCENE := preload("res://ui/loading_screen/loading_screen.tscn")

var timer: Timer

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.autostart = false
	add_child(timer)

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

	var loading_screen = _LOADING_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(loading_screen)
	await loading_screen.fade_out() # Wait for fade to black

	var res = ResourceLoader.load(path)
	var save := res as SaveGame
	if save == null:
		loading_screen.fade_in() # Fade back in if load failed
		loading_screen.queue_free()
		return false

	if not GridState:
		loading_screen.fade_in()
		loading_screen.queue_free()
		return false

	var success = _GRID_SERIALIZER.restore(GridState, save)

	timer.start()
	await timer.timeout
	await loading_screen.fade_in()
	loading_screen.queue_free()
	return success
