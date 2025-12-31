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

	# Prefer a debug getter so changes in WorldGrid internals don't silently break this overlay.
	var grid_data: Dictionary = {}
	if WorldGrid and WorldGrid.has_method("debug_get_grid_data"):
		grid_data = WorldGrid.debug_get_grid_data()

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

	# Overlay: Markers and Agents
	_draw_markers(tile_size)
	_draw_agents(tile_size)

func _draw_markers(_tile_size: Vector2) -> void:
	if not _parent_map:
		return
	var root = _parent_map.get_parent() # Likely LevelRoot or similar
	if not root: 
		# If level structure is different (e.g. Ground is grandchild), try finding LevelRoot
		var p = _parent_map
		while p and not (p is LevelRoot) and p != get_tree().root:
			p = p.get_parent()
		root = p
	
	if not root: return
	
	# Spawns
	var spawns = get_tree().get_nodes_in_group(Groups.SPAWN_MARKERS)
	for node in spawns:
		if not (node is Node2D): continue
		# Only draw if under current level root (approximate check)
		# Or if they are in the scene tree.
		# Note: get_nodes_in_group returns all in tree. We only want visible ones in this scene.
		# If they are in the active scene, they are relevant.
		
		var pos = to_local(node.global_position)
		draw_circle(pos, 4, Color.YELLOW)
		draw_string(_font, pos + Vector2(5, 5), "S:%s" % str(node.get("spawn_id")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)

	# Travel Zones
	# Recursively find travel zones since they might not be in a group
	var travel_zones = _find_travel_zones_recursive(root)
	for tz in travel_zones:
		if not (tz is Node2D): continue
		var pos = to_local(tz.global_position)
		draw_circle(pos, 4, Color.MAGENTA)
		var dest = str(tz.target_level_id)
		draw_string(_font, pos + Vector2(5, 5), "TZ->%s" % dest, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.MAGENTA)

func _find_travel_zones_recursive(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	if node is TravelZone:
		out.append(node)
	
	for c in node.get_children():
		out.append_array(_find_travel_zones_recursive(c))
	return out

func _draw_agents(_tile_size: Vector2) -> void:
	# 1. Active Agents (Groups.AGENT_COMPONENTS)
	var active_ids = {}
	var agent_nodes = get_tree().get_nodes_in_group(Groups.AGENT_COMPONENTS)
	
	for ac in agent_nodes:
		if not (ac is AgentComponent): continue
		var host = ac.get_parent()
		if host.name == "Components": host = host.get_parent()
		if not (host is Node2D): continue
		
		var pos = to_local(host.global_position)
		var color = Color.CYAN if ac.kind == Enums.AgentKind.PLAYER else Color.RED
		
		draw_circle(pos, 5, color)
		draw_string(_font, pos + Vector2(-10, -10), str(ac.agent_id), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, color)
		active_ids[ac.agent_id] = true
		
		# Draw intent if any
		if AgentRegistry:
			var rec = AgentRegistry.get_record(ac.agent_id)
			if rec and rec.pending_level_id != Enums.Levels.NONE:
				draw_string(_font, pos + Vector2(10, 0), "->%s" % rec.pending_level_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.ORANGE)

	# 2. Offline/Ghost Agents (AgentRegistry)
	if AgentRegistry:
		var level_id = -1
		if GameManager: level_id = GameManager.get_active_level_id()
		
		var agents = AgentRegistry.debug_get_agents()
		for id in agents:
			if active_ids.has(id): continue
			var rec = agents[id]
			if int(rec.current_level_id) == int(level_id):
				var pos = to_local(rec.last_world_pos)
				draw_circle(pos, 4, Color.GRAY)
				draw_string(_font, pos + Vector2(-10, -10), "%s(off)" % id, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.GRAY)
