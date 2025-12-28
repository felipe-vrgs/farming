class_name RayCellComponent
extends Node

@export var interact_distance: float = 12.0
@export var debug_enabled: bool = false

var facing_dir: Vector2 = Vector2.DOWN
var ray: RayCast2D
var _ground_layer: TileMapLayer
var _debug_drawer: Node2D

func _ready() -> void:
	_ground_layer = _resolve_ground_layer()
	ray = RayCast2D.new()
	# We set global pos initially, but update_aim handles it frame-by-frame
	ray.global_position = get_parent().global_position
	ray.target_position = Vector2.RIGHT * interact_distance
	ray.collision_mask = 14
	ray.collide_with_areas = true
	get_parent().add_child(ray)

	if debug_enabled:
		_debug_drawer = Node2D.new()
		_debug_drawer.z_index = 100
		_debug_drawer.draw.connect(_on_debug_draw)
		add_child(_debug_drawer)

func _process(_delta: float) -> void:
	if debug_enabled and _debug_drawer:
		_debug_drawer.queue_redraw()

func _on_debug_draw() -> void:
	if not ray:
		return

	# Draw Ray
	# ray.global_position is managed by update_aim, which aligns it with player.
	# _debug_drawer is child of this component (Node), child of Player (Node2D).
	# So _debug_drawer origin is effectively Player origin.

	var start_pos = _debug_drawer.to_local(ray.global_position)
	var end_pos = _debug_drawer.to_local(ray.global_position + ray.target_position)

	_debug_drawer.draw_line(start_pos, end_pos, Color.RED, 2.0)

	# Draw Target Cell
	var cell = get_front_cell()
	if cell != null and cell is Vector2i:
		var center = cell_to_global_center(cell)
		var local_center = _debug_drawer.to_local(center)
		# Assuming 16x16 tile size approx, or fetch from layer if possible
		var size = Vector2(16, 16)
		if _ground_layer and _ground_layer.tile_set:
			size = Vector2(_ground_layer.tile_set.tile_size)

		var rect = Rect2(local_center - size/2, size)
		_debug_drawer.draw_rect(rect, Color(1, 0, 0, 0.4), true)
		_debug_drawer.draw_rect(rect, Color.RED, false, 1.0)

func update_aim(velocity: Vector2, position: Vector2) -> void:
	if velocity.length() > 0.1:
		# Simplify to 4 cardinal directions (Left, Right, Up, Down)
		var raw_dir = velocity
		if abs(raw_dir.x) >= abs(raw_dir.y):
			facing_dir = Vector2.RIGHT if raw_dir.x > 0 else Vector2.LEFT
		else:
			facing_dir = Vector2.DOWN if raw_dir.y > 0 else Vector2.UP

	ray.global_position = position
	ray.target_position = facing_dir * interact_distance

func get_global_position() -> Vector2:
	return ray.global_position

func get_front_cell() -> Variant:
	var tip_global = get_global_position() + ray.target_position
	return _get_cell_at_pos(tip_global)

func cell_to_global_center(cell: Vector2i) -> Vector2:
	if _ground_layer == null:
		_ground_layer = _resolve_ground_layer()

	var local_pos := _ground_layer.map_to_local(cell)
	return _ground_layer.to_global(local_pos)

func _get_cell_at_pos(global_pos: Vector2) -> Variant:
	if _ground_layer == null:
		_ground_layer = _resolve_ground_layer()
		if _ground_layer == null:
			return null

	var cell: Vector2i = _ground_layer.local_to_map(_ground_layer.to_local(global_pos))
	if _ground_layer.get_cell_source_id(cell) != -1:
		return cell
	return null

func _resolve_ground_layer() -> TileMapLayer:
	var scene := get_tree().current_scene
	if scene == null:
		return null

	return scene.get_node_or_null(NodePath("GroundMaps/Ground"))
