class_name InteractivityManager
extends Node

## TileMapLayer names (under `Main/GroundMaps`) to scan for interactions, in priority order.
@export var tile_layer_names: Array[StringName] = [
	&"Decor",
	&"Tops",
	&"Walls",
	&"SoilWetOverlay",
	&"SoilOverlay",
	&"Ground",
	&"Shadows",
	&"Background",
]

var facing_dir: Vector2 = Vector2.DOWN
var _tile_layers: Array[TileMapLayer] = []

func _ready() -> void:
	_tile_layers = _resolve_tile_layers()

func update_aim(player: Player) -> void:
	if player == null:
		return

	if player.velocity.length() > 0.1:
		# Simplify to 4 cardinal directions (Left, Right, Up, Down)
		var raw_dir = player.velocity
		if abs(raw_dir.x) >= abs(raw_dir.y):
			facing_dir = Vector2.RIGHT if raw_dir.x > 0 else Vector2.LEFT
		else:
			facing_dir = Vector2.DOWN if raw_dir.y > 0 else Vector2.UP

	# We use a slightly offset center to ensure we pick the tile *in front* comfortably
	# Respect editor position for RayCast2D, just update target vector.
	player.interact_ray.target_position = facing_dir * player.interact_distance

func interact(player: Player) -> void:
	if player == null or player.equipped_tool == null:
		return

	# Keep ray direction and facing in sync right before interacting.
	update_aim(player)

	# 1) Prefer entity/area interactions via raycast (trees, chests, NPCs, etc.)
	player.interact_ray.force_raycast_update()
	if player.interact_ray.is_colliding():
		var collider = player.interact_ray.get_collider()
		# If later you add Tree scenes etc, this is where you'd dispatch first.
		# For now we fall through to tile-based interactions as well.

	# 2) Tile-based interaction:
	# Get the tile exactly where the ray ends.
	var target_cell = _get_front_cell(player)

	if target_cell == null:
		return

	SoilGridState.try_use_tool(player.equipped_tool, target_cell)

func _get_front_cell(player: Player) -> Variant:
	if _tile_layers.is_empty():
		_tile_layers = _resolve_tile_layers()
		if _tile_layers.is_empty():
			return null

	# Calculate global position of the ray tip
	# We rely on player.interact_ray having the correct position (set in editor)
	# and target_position (set in update_aim).
	var tip_global = player.interact_ray.global_position + player.interact_ray.target_position

	return _get_cell_at_pos(tip_global)

func _get_cell_at_pos(global_pos: Vector2) -> Variant:
	for layer in _tile_layers:
		if layer == null:
			continue
		var cell: Vector2i = layer.local_to_map(layer.to_local(global_pos))
		if layer.get_cell_source_id(cell) != -1:
			return cell
	return null

func _resolve_tile_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	var scene := get_tree().current_scene
	if scene == null:
		return layers

	var ground_maps := scene.get_node_or_null(NodePath("GroundMaps"))
	if ground_maps == null:
		return layers

	for tile_layer_name in tile_layer_names:
		var n := ground_maps.get_node_or_null(NodePath(String(tile_layer_name)))
		if n is TileMapLayer:
			layers.append(n)

	return layers
