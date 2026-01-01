class_name GridDebugModule
extends DebugGridModule

var _enabled: bool = false
var _parent_map: TileMapLayer

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			_enabled = not _enabled
			_debug_grid.queue_redraw()

func _draw(tile_size: Vector2) -> void:
	if not _enabled:
		return

	# Try to find the ground layer reference if we haven't already
	if not _parent_map:
		var scene = _debug_grid.get_tree().current_scene
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
		_debug_grid.draw_string(
			_font,
			Vector2(10, 20),
			"Debug: No Ground Layer found",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.RED
		)
		return

	var grid_data: Dictionary = {}
	if WorldGrid and WorldGrid.has_method("debug_get_grid_data"):
		grid_data = WorldGrid.debug_get_grid_data()

	var actual_tile_size := tile_size
	if _parent_map.tile_set and _parent_map.tile_set.tile_size != Vector2i.ZERO:
		actual_tile_size = Vector2(_parent_map.tile_set.tile_size)

	for cell in grid_data:
		var data = grid_data[cell] as GridCellData
		if not data:
			continue

		var local_pos = _parent_map.map_to_local(cell)
		var global_pos_cell = _parent_map.to_global(local_pos)
		var draw_pos = _debug_grid.to_local(global_pos_cell)

		var rect = Rect2(draw_pos - actual_tile_size/2, actual_tile_size)

		var color = Color.WHITE
		match data.terrain_id:
			GridCellData.TerrainType.GRASS: color = Color.GREEN.darkened(0.5)
			GridCellData.TerrainType.DIRT: color = Color.SADDLE_BROWN
			GridCellData.TerrainType.SOIL: color = Color.ORANGE
			GridCellData.TerrainType.SOIL_WET: color = Color.CORNFLOWER_BLUE

		_debug_grid.draw_rect(rect, Color(color.r, color.g, color.b, 0.3), true)
		_debug_grid.draw_rect(rect, color, false, 1.0)

		if data.is_wet():
			_debug_grid.draw_string(
				_font,
				draw_pos + Vector2(-4, 4),
				"W",
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				8,
				Color.CYAN
			)

		var markers: Array[String] = []
		var plant_details: String = ""

		if data.entities:
			for t in data.entities.keys():
				match int(t):
					Enums.EntityType.PLANT:
						var plant_entity = data.get_entity_of_type(Enums.EntityType.PLANT)
						if plant_entity is Plant:
							var p := plant_entity as Plant
							plant_details = "%d/%d" % [p.days_grown, p.get_stage_idx()]
						markers.append("P")
					Enums.EntityType.TREE: markers.append("T")
					Enums.EntityType.ROCK: markers.append("R")
					Enums.EntityType.BUILDING: markers.append("B")
					Enums.EntityType.PLAYER: pass
					Enums.EntityType.NPC: pass
					_: markers.append("E")

		if not markers.is_empty():
			var s = " ".join(markers)
			_debug_grid.draw_string(
				_font,
				draw_pos + Vector2(0, -2),
				s,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				6,
				Color.WHITE
			)

		if not plant_details.is_empty():
			_debug_grid.draw_string(
				_font,
				draw_pos + Vector2(0, 6),
				plant_details,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				6,
				Color.GREEN_YELLOW
			)

func is_enabled() -> bool:
	return _enabled
