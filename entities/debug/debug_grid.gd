class_name DebugGrid
extends Node2D

var _font: Font
var _enabled: bool = false
var _parent_map: TileMapLayer

func _ready() -> void:
	visible = false
	z_index = 100 # Draw on top
	_font = ThemeDB.fallback_font

	# Connect to grid updates for efficient redrawing
	SoilGridState.grid_changed.connect(_on_grid_changed)

func _on_grid_changed(_cell: Vector2i) -> void:
	if _enabled:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_enabled = not _enabled
		visible = _enabled
		queue_redraw()

func _draw() -> void:
	if not _enabled:
		return

	# Try to find the ground layer reference if we haven't already
	if not _parent_map:
		var scene = get_tree().current_scene
		if scene:
			_parent_map = scene.get_node_or_null("GroundMaps/Ground")

	if not _parent_map:
		draw_string(
			_font,
			Vector2(10, 20),
			"Debug: No Ground Layer found",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.RED
		)
		return

	# Access private data for debug purposes (or add a getter to SoilGridState)
	var grid_data: Dictionary = SoilGridState._grid_data

	# Assuming 16x16 tiles (check tile_set if possible, but 16 is standard here)
	var tile_size = Vector2(16, 16)

	for cell in grid_data:
		var data = grid_data[cell] as GridCellData
		if not data:
			continue

		# Convert map coords to global position then to our local position
		var local_pos = _parent_map.map_to_local(cell)
		var global_pos_cell = _parent_map.to_global(local_pos)
		var draw_pos = to_local(global_pos_cell)

		# Draw rect centered on the tile
		var rect = Rect2(draw_pos - tile_size/2, tile_size)

		var color = Color.WHITE
		match data.terrain_id:
			GridCellData.TerrainType.GRASS: color = Color.GREEN.darkened(0.5)
			GridCellData.TerrainType.DIRT: color = Color.SADDLE_BROWN
			GridCellData.TerrainType.SOIL: color = Color.ORANGE
			GridCellData.TerrainType.SOIL_WET: color = Color.CORNFLOWER_BLUE

		# Fill with transparency
		# draw_rect(rect, color, true) # Godot draw_rect fill is default? No, need to set color alpha
		draw_rect(rect, Color(color.r, color.g, color.b, 0.3), true)

		# Border
		draw_rect(rect, color, false, 1.0)

		# Info Text
		if data.is_wet:
			draw_string(
				_font,
				draw_pos + Vector2(-4, 4),
				"W",
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				8,
				Color.CYAN
			)

		if not String(data.plant_id).is_empty():
			draw_circle(draw_pos + Vector2(4, -4), 2.0, Color.YELLOW)