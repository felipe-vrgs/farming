extends Node

## Debug module entrypoint.
##
## This script is intended to be configured as a single autoload (e.g. `Debug`)
## and will spawn debug-only scenes as children when running in a debug build.
##
## It also stays disabled in headless test runs (`FARMING_TEST_MODE=1`).

const _CONSOLE_SCENE := preload("res://debug/console/game_console.tscn")
const _GRID_SCENE := preload("res://debug/grid/debug_grid.tscn")

var console: CanvasLayer = null
var grid: Node2D = null


func _ready() -> void:
	# Never run debug tools in headless tests, even if the editor/debug build is used.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		queue_free()
		return

	# Debug-only in shipped builds.
	if not OS.is_debug_build():
		queue_free()
		return

	console = _CONSOLE_SCENE.instantiate() as CanvasLayer
	if console != null:
		console.name = "GameConsole"
		add_child(console)

	grid = _GRID_SCENE.instantiate() as Node2D
	if grid != null:
		grid.name = "DebugGrid"
		add_child(grid)
