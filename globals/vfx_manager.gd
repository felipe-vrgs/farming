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
		_spawn_batch(cells, water_splash_scene, 10, null)
		return

	# Transition: Drying (Wet -> Soil) - No VFX
	if from_wet and (to_terrain == GridCellData.TerrainType.SOIL):
		return

	# Transition: Breaking/Tilling (Default fallback)
	# This covers Grass->Dirt, Dirt->Soil, etc.
	_spawn_batch(cells, tile_break_scene, 5, true)

func _spawn_batch(
	cells: Array[Vector2i],
	scene: PackedScene,
	z_index: int,
	color_source: Variant = null
) -> void:
	for cell in cells:
		var pos = TileMapManager.cell_to_global(cell) + Vector2(8, 8)
		var vfx = _spawn_vfx(scene, pos, z_index)

		if vfx and color_source == true:
			# If color_source is true, sample from tile
			var tex = TileMapManager.get_top_visible_texture(cell)
			if tex:
				vfx.setup_visuals(_sample_average_color(tex))
		elif vfx and color_source == null:
			# Manual color override for water (could be in the scene itself, but here for safety)
			vfx.setup_visuals(Color(0.4, 0.7, 1.0, 1.0))
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
