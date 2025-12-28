extends Node2D

var _font: Font
var _enabled: bool = false
var _parent_map: TileMapLayer

@onready var _timer: Timer = $Timer

func _ready() -> void:
	visible = false
	z_index = 100 # Draw on top
	_font = ThemeDB.fallback_font

	# Polling for grid updates every second
	_timer.timeout.connect(_on_poll_timer_timeout)

func _on_poll_timer_timeout() -> void:
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
			if scene is LevelRoot:
				_parent_map = (scene as LevelRoot).get_ground_layer()
			else:
				var lr = scene.get_node_or_null("LevelRoot")
				if lr is LevelRoot:
					_parent_map = (lr as LevelRoot).get_ground_layer()
				else:
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

	# Prefer a debug getter so changes in GridState internals don't silently break this overlay.
	var grid_data: Dictionary = {}
	if GridState and GridState.has_method("debug_get_grid_data"):
		grid_data = GridState.debug_get_grid_data()
	else:
		# Fallback (best-effort).
		grid_data = GridState._grid_data

	# Prefer actual TileSet tile size; fallback to 16x16.
	var tile_size := Vector2(16, 16)
	if _parent_map.tile_set and _parent_map.tile_set.tile_size != Vector2i.ZERO:
		tile_size = Vector2(_parent_map.tile_set.tile_size)

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
		if data.is_wet():
			draw_string(
				_font,
				draw_pos + Vector2(-4, 4),
				"W",
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				8,
				Color.CYAN
			)

		# Show entity markers (types + plant growth details).
		var markers: Array[String] = []
		if data.entities:
			for t in data.entities.keys():
				match int(t):
					Enums.EntityType.PLANT: markers.append("P")
					Enums.EntityType.TREE: markers.append("T")
					Enums.EntityType.ROCK: markers.append("R")
					Enums.EntityType.BUILDING: markers.append("B")
					_: markers.append("E")

		var plant_entity = data.get_entity_of_type(Enums.EntityType.PLANT)
		if plant_entity is Plant:
			var p := plant_entity as Plant
			markers.append("d=%d s=%d" % [p.days_grown, p.get_stage_idx()])

		if markers.size() > 0:
			draw_string(
				_font,
				draw_pos + Vector2(-tile_size.x * 0.45, -tile_size.y * 0.35),
				" ".join(markers),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				8,
				Color.WHITE
			)
