class_name RayCellComponent
extends Node

@export var interact_distance: float = 12.0
@export var debug_enabled: bool = false
@export var use_cast_radius: float = 6.0

var facing_dir: Vector2 = Vector2.DOWN
var ray: RayCast2D
var use_cast: ShapeCast2D
var _debug_drawer: Node2D


func _ready() -> void:
	ray = RayCast2D.new()
	# We set global pos initially, but update_aim handles it frame-by-frame
	ray.global_position = get_parent().global_position
	ray.target_position = Vector2.RIGHT * interact_distance
	ray.collision_mask = 14
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.enabled = true
	# Avoid "Parent node is busy setting up children" on startup.
	get_parent().add_child.call_deferred(ray)

	# Thick cast for "USE" targeting (more forgiving than a thin ray).
	use_cast = ShapeCast2D.new()
	use_cast.global_position = get_parent().global_position
	use_cast.target_position = Vector2.RIGHT * interact_distance
	use_cast.collision_mask = 14
	use_cast.collide_with_areas = true
	use_cast.collide_with_bodies = true
	use_cast.enabled = true

	var shape := CircleShape2D.new()
	shape.radius = maxf(0.0, use_cast_radius)
	use_cast.shape = shape
	get_parent().add_child.call_deferred(use_cast)

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
		# Assuming 16x16 tile size
		var size = Vector2(16, 16)
		var rect = Rect2(local_center - size / 2, size)
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
	if use_cast:
		use_cast.global_position = position
		use_cast.target_position = facing_dir * interact_distance


func get_global_position() -> Vector2:
	return ray.global_position


func get_front_cell() -> Variant:
	var tip_global = get_global_position() + ray.target_position
	return _get_cell_at_pos(tip_global)


func cell_to_global_center(cell: Vector2i) -> Vector2:
	return WorldGrid.tile_map.cell_to_global(cell)


func _get_cell_at_pos(global_pos: Vector2) -> Variant:
	return WorldGrid.tile_map.global_to_cell(global_pos)


func get_use_colliders() -> Array[Node]:
	# Returns colliders hit by the thick use cast (nearest-first if possible).
	var out: Array[Node] = []
	if use_cast == null or not is_instance_valid(use_cast):
		return out
	if not use_cast.is_colliding():
		return out

	var count := use_cast.get_collision_count()
	for i in range(count):
		var c = use_cast.get_collider(i)
		if c is Node:
			out.append(c as Node)
	return out
