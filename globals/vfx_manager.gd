extends Node

## Global manager for spawning one-shot visual effects.
const TILE_BREAK_SCENE_PATH := "res://entities/particles/effects/tile_break_vfx.tscn"
const WATER_SPLASH_SCENE_PATH := "res://entities/particles/effects/water_splash_vfx.tscn"

var tile_break_scene: PackedScene = preload(TILE_BREAK_SCENE_PATH)
var water_splash_scene: PackedScene = preload(WATER_SPLASH_SCENE_PATH)

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

	# Watering: SOIL -> SOIL_WET (or any non-wet -> wet transition).
	if (not from_wet) and to_wet:
		for cell in cells:
			trigger_water_splash(cell)
		return

	# Drying: SOIL_WET -> SOIL (no VFX)
	if from_wet and (to_terrain == GridCellData.TerrainType.SOIL):
		return

	# Everything else is a "break" style change (including clearing wet soil to dirt).
	for cell in cells:
		trigger_tile_break(cell)

func trigger_water_splash(cell: Vector2i) -> void:
	var pos = TileMapManager.cell_to_global(cell) + Vector2(8, 8)
	var vfx = _spawn_vfx(water_splash_scene, pos, 10)
	if vfx == null:
		return
	# Configure Visuals: Blue color
	vfx.setup_visuals(Color(0.4, 0.7, 1.0, 1.0))
	vfx.play()

func trigger_tile_break(cell: Vector2i) -> void:
	var tex = TileMapManager.get_top_visible_texture(cell)
	if tex == null:
		return

	var pos = TileMapManager.cell_to_global(cell) + Vector2(8, 8)
	var vfx = _spawn_vfx(tile_break_scene, pos, 5)
	if vfx == null:
		return
	var color = _sample_average_color(tex)
	vfx.setup_visuals(color)
	vfx.play()

func _sample_average_color(tex: Texture2D) -> Color:
	if tex is AtlasTexture:
		var image = tex.atlas.get_image()
		if not image: return Color.BROWN

		var region = tex.region
		var cx = int(region.position.x + region.size.x * 0.5)
		var cy = int(region.position.y + region.size.y * 0.5)

		cx = clampi(cx, 0, image.get_width() - 1)
		cy = clampi(cy, 0, image.get_height() - 1)

		return image.get_pixel(cx, cy)
	if tex != null:
		var image = tex.get_image()
		if not image: return Color.BROWN
		return image.get_pixel(
			ceil(image.get_width() / 2.0),
			ceil(image.get_height() / 2.0)
		)

	return Color.BROWN
