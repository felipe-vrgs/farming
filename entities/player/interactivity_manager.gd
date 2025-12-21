class_name InteractivityManager
extends Node

## TileMapLayer names (under `Main/GroundMaps`) to scan for interactions, in priority order.
@export var tile_layer_names: Array[StringName] = [
	&"Decor",
	&"Tops",
	&"Walls",
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
		facing_dir = player.velocity.normalized()

	player.interact_ray.target_position = facing_dir.normalized() * player.interact_distance

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

	# 2) Tile-based interaction: compute the cell in front by scanning layers.
	var cell = _get_front_cell(player)
	if cell == null:
		return

	SoilGridState.try_use_tool(player.equipped_tool, cell)

func _get_front_cell(player: Player) -> Variant:
	if _tile_layers.is_empty():
		_tile_layers = _resolve_tile_layers()
		if _tile_layers.is_empty():
			return null

	var front_global := (
		player.global_position
		+ (facing_dir.normalized() * player.interact_distance)
	)

	for layer in _tile_layers:
		if layer == null:
			continue
		var cell: Vector2i = layer.local_to_map(layer.to_local(front_global))
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

	for name in tile_layer_names:
		var n := ground_maps.get_node_or_null(NodePath(String(name)))
		if n is TileMapLayer:
			layers.append(n)

	return layers
