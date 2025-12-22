class_name InteractivityManager
extends Node

var facing_dir: Vector2 = Vector2.DOWN
var _ground_layer: TileMapLayer

func _ready() -> void:
	_ground_layer = _resolve_ground_layer()

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

func get_front_cell(player: Player) -> Variant:
	var tip_global = player.interact_ray.global_position + player.interact_ray.target_position
	return _get_cell_at_pos(tip_global)

func cell_to_global_center(cell: Vector2i) -> Vector2:
	if _ground_layer == null:
		_ground_layer = _resolve_ground_layer()

	var local_pos := _ground_layer.map_to_local(cell)
	return _ground_layer.to_global(local_pos)

func _get_cell_at_pos(global_pos: Vector2) -> Variant:
	var cell: Vector2i = _ground_layer.local_to_map(_ground_layer.to_local(global_pos))
	if _ground_layer.get_cell_source_id(cell) != -1:
		return cell
	return null

func _resolve_ground_layer() -> TileMapLayer:
	var scene := get_tree().current_scene
	if scene == null:
		return null

	return scene.get_node_or_null(NodePath("GroundMaps/Ground"))
