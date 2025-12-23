extends Node

## Global manager for spawning one-shot visual effects.
var tile_break_scene = preload("res://entities/particles/effects/tile_break_vfx.tscn")
var water_splash_scene = preload("res://entities/particles/effects/water_splash_vfx.tscn")

func _ready() -> void:
	# Subscribe to world events.
	if EventBus:
		EventBus.terrain_changed.connect(_on_terrain_changed)

func _spawn_vfx(scene: PackedScene, pos: Vector2, z_index: int) -> VFX:
	if scene == null:
		return null
	var instance = scene.instantiate()
	if instance is VFX:
		instance.top_level = true
		instance.z_index = z_index
		instance.global_position = pos
	add_child(instance)
	return instance

func _on_terrain_changed(cells: Array[Vector2i], from_terrain: int, to_terrain: int) -> void:
	var from_wet := from_terrain == GridCellData.TerrainType.SOIL_WET
	var to_wet := to_terrain == GridCellData.TerrainType.SOIL_WET

	# Transition: Watering (Any -> Wet)
	if (not from_wet) and to_wet:
		_spawn_batch(cells, water_splash_scene, 10, [Color(0.4, 0.7, 1.0), Color(0.6, 0.9, 1.0)])
		return

	# Transition: Drying (Wet -> Soil) - No VFX
	if from_wet and (to_terrain == GridCellData.TerrainType.SOIL):
		return

	var col_from = _get_terrain_color(from_terrain)
	var col_to = _get_terrain_color(to_terrain)

	_spawn_batch(cells, tile_break_scene, 5, [col_from, col_to])

func _get_terrain_color(terrain: int) -> Color:
	if GridCellData.TERRAIN_COLORS.has(terrain):
		return GridCellData.TERRAIN_COLORS[terrain]
	return Color.BROWN

func _spawn_batch(
	cells: Array[Vector2i],
	scene: PackedScene,
	z_index: int,
	colors: Variant = null
) -> void:
	for cell in cells:
		var vfx = _spawn_vfx(scene, TileMapManager.cell_to_global(cell), z_index)
		if vfx:
			if colors is Array:
				vfx.setup_colors(colors)
			elif colors is Color:
				vfx.setup_visuals(colors)
			elif colors == null:
				# Default water splash colors if none provided
				vfx.setup_colors([Color(0.4, 0.7, 1.0), Color(0.2, 0.5, 0.9)])
			vfx.play()
