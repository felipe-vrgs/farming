extends Node

# Resources
var pool_scene: PackedScene = preload("res://entities/particles/vfx.tscn")
var puff_config = preload("res://entities/particles/resources/walk_puff.tres")
var tile_break_config = preload("res://entities/particles/resources/tile_break.tres")
var water_splash_config = preload("res://entities/particles/resources/water_splash.tres")

## Global manager for spawning one-shot visual effects.
var _vfx_pool: Array[Node2D] = []
var _pool_size: int = 30 # Increased for multiple effect types
var _pool_index: int = 0

func _ready() -> void:
	if EventBus:
		EventBus.terrain_changed.connect(_on_terrain_changed)
		EventBus.player_moved_to_cell.connect(_on_player_moved_to_cell)
	_init_pool()

func _init_pool() -> void:
	for i in range(_pool_size):
		var instance = pool_scene.instantiate() as Node2D
		add_child(instance)
		instance.visible = false
		_vfx_pool.append(instance)

func _spawn_effect(config: Resource, pos: Vector2, z_index: int, colors: Array = []) -> void:
	if config == null: return
	var instance = _vfx_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool_size
	# Setup the generic instance with this specific config
	if instance.has_method("setup"):
		instance.call("setup", config)
	if instance.has_method("play"):
		instance.call("play", pos, z_index, colors)

func _on_player_moved_to_cell(cell: Vector2i, player_pos: Vector2) -> void:
	var terrain = TileMapManager.get_terrain_at(cell)
	var color = _get_terrain_color(terrain)
	if color == Color.BROWN: return # No void/default
	# Pass in the config and the dynamic colors
	_spawn_effect(puff_config, player_pos, 5, [color, GridCellData.TERRAIN_COLORS_VARIANT[terrain]])

func _on_terrain_changed(cells: Array[Vector2i], from_terrain: int, to_terrain: int) -> void:
	var from_wet := from_terrain == GridCellData.TerrainType.SOIL_WET
	var to_wet := to_terrain == GridCellData.TerrainType.SOIL_WET

	# Transition: Watering (Any -> Wet)
	if (not from_wet) and to_wet:
		_spawn_batch(cells, water_splash_config, 10, [Color(0.4, 0.7, 1.0), Color(0.6, 0.9, 1.0)])
		return

	# Transition: Drying (Wet -> Soil) - No VFX
	if from_wet and (to_terrain == GridCellData.TerrainType.SOIL):
		return

	var col_from = _get_terrain_color(from_terrain)
	var col_to = _get_terrain_color(to_terrain)

	_spawn_batch(cells, tile_break_config, 5, [col_from, col_to])

func _get_terrain_color(terrain: int) -> Color:
	if GridCellData.TERRAIN_COLORS.has(terrain):
		return GridCellData.TERRAIN_COLORS[terrain]
	return Color.BROWN

func _spawn_batch(
	cells: Array[Vector2i],
	config: Resource,
	z_index: int,
	colors: Variant = null
) -> void:
	var colors_arr: Array = []
	if colors is Array:
		colors_arr = colors
	elif colors is Color:
		colors_arr = [colors]
	for cell in cells:
		_spawn_effect(config, TileMapManager.cell_to_global(cell), z_index, colors_arr)
