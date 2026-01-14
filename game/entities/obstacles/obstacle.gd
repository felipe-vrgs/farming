@tool
class_name Obstacle
extends Node2D

## Generic data-driven obstacle entity.
## - Builds visuals + collisions.
## - Registers grid occupancy via GridOccupantComponent based on the collision rectangle.

var _rotate_degrees: int = 0
# Cached collision rect for anchor computations.
var _collision_offset_local: Vector2 = Vector2.ZERO
var _collision_size_local: Vector2 = Vector2(16, 16)
# NOTE: Without explicit values ("90:90"), Godot stores enum indices (0..3),
# which would make selecting "90" set the value to 1. We want real degrees.
@export_enum("0:0", "90:90", "180:180", "270:270") var rotate_degrees: int:
	get:
		return _rotate_degrees
	set(v):
		# Normalize for code callers (and recover from older serialized values that may have
		# stored enum indices 0..3).
		var vv := int(v)
		if vv >= 0 and vv <= 3 and vv not in [0, 90, 180, 270]:
			vv *= 90
		vv = vv % 360
		if vv < 0:
			vv += 360
		# Snap to nearest right angle.
		_rotate_degrees = int(round(float(vv) / 90.0)) * 90
		if _rotate_degrees == 360:
			_rotate_degrees = 0
		_apply_rotation()

@export var data: ObstacleData:
	set(v):
		if data == v:
			# Still re-apply to keep tool scripts predictable.
			_apply_data()
			return
		_disconnect_data()
		data = v
		_connect_data()
		_apply_data()


func _enter_tree() -> void:
	# If the resource is already assigned (scene load), ensure we listen for edits.
	_connect_data()


func _ready() -> void:
	_apply_rotation()
	_apply_data()


func _exit_tree() -> void:
	_disconnect_data()


func _connect_data() -> void:
	if data == null:
		return
	if not data.changed.is_connected(_on_data_changed):
		data.changed.connect(_on_data_changed)


func _disconnect_data() -> void:
	if data == null:
		return
	if data.changed.is_connected(_on_data_changed):
		data.changed.disconnect(_on_data_changed)


func _on_data_changed() -> void:
	_apply_data()


## Apply config directly from a preset resource (used by per-instance variant scenes).
func apply_preset(preset: ObstaclePreset) -> void:
	if preset == null:
		return
	_apply_values(
		preset.texture,
		preset.centered,
		preset.sprite_offset,
		preset.collision_size,
		preset.collision_offset,
		preset.collision_layer,
		preset.collision_mask,
		preset.entity_type
	)


func _apply_data() -> void:
	if data == null:
		return
	# Defensive: scene serialization or editor operations can temporarily assign wrong resources.
	# Keep tool mode stable instead of crashing on `data.texture` access.
	if not (data is ObstacleData):
		return
	_apply_values(
		data.texture,
		data.centered,
		data.sprite_offset,
		data.collision_size,
		data.collision_offset,
		data.collision_layer,
		data.collision_mask,
		data.entity_type
	)


func _apply_values(
	texture: Texture2D,
	centered: bool,
	sprite_offset: Vector2,
	collision_size: Vector2,
	collision_offset: Vector2,
	collision_layer: int,
	collision_mask: int,
	entity_type: Enums.EntityType
) -> void:
	var sprite := _get_or_create_sprite()
	sprite.texture = texture
	sprite.centered = centered
	sprite.position = sprite_offset

	var body := _get_or_create_body()
	body.collision_layer = collision_layer
	body.collision_mask = collision_mask

	var cs := _get_or_create_collision_shape(body)
	cs.position = collision_offset
	var rect := cs.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		cs.shape = rect
	else:
		# IMPORTANT:
		# When a CollisionShape2D's shape comes from a PackedScene sub-resource,
		# Godot can share the same RectangleShape2D resource across multiple instances.
		# If we mutate `rect.size` directly, we may accidentally change ALL instances'
		# hitboxes. Duplicate to ensure this instance owns its shape.
		if not rect.resource_local_to_scene:
			var rect_copy := rect.duplicate() as RectangleShape2D
			rect_copy.resource_local_to_scene = true
			cs.shape = rect_copy
			rect = rect_copy
	rect.size = collision_size

	var occ := _get_or_create_occupant()
	occ.entity_type = entity_type
	occ.collision_shape = cs
	# If this obstacle is live in a scene, refresh its registered grid footprint.
	if occ.is_inside_tree():
		occ.register_from_current_position()

	# Cache collision rect for stable anchoring across rotations.
	_collision_offset_local = collision_offset
	_collision_size_local = collision_size
	_apply_rotation()


func _apply_rotation() -> void:
	var visual := _get_or_create_visual()
	var rad := deg_to_rad(float(_rotate_degrees))
	visual.rotation = rad

	# Anchor the *lowest* part of the collision rect to the root origin.
	# This keeps the "ground contact" stable even when rotating 90/180/270.
	var half := _collision_size_local * 0.5
	var corners := PackedVector2Array(
		[
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		]
	)

	var max_y := -INF
	var rotated_points: Array[Vector2] = []
	rotated_points.resize(corners.size())

	for i in range(corners.size()):
		var p_local := _collision_offset_local + corners[i]
		var p_rot := p_local.rotated(rad)
		rotated_points[i] = p_rot
		max_y = maxf(max_y, p_rot.y)

	# Collect all points on the lowest edge (max Y) and average them.
	var eps := 0.001
	var sum := Vector2.ZERO
	var count := 0
	for p in rotated_points:
		if absf(p.y - max_y) <= eps:
			sum += p
			count += 1

	var anchor_rot := Vector2.ZERO
	if count > 0:
		anchor_rot = sum / float(count)
	else:
		# Fallback: should never happen, but keep behavior deterministic.
		anchor_rot = Vector2(0, max_y)

	visual.position = -anchor_rot


func _editor_owner() -> Node:
	# Ensures created nodes persist in the edited scene.
	if not Engine.is_editor_hint():
		return null
	var o := owner
	if o != null:
		return o
	var root := get_tree().edited_scene_root
	return root


func _get_or_create_visual() -> Node2D:
	var n := get_node_or_null(NodePath("Visual"))
	if n is Node2D:
		return n as Node2D

	# Create the container and opportunistically migrate old hierarchy (Sprite2D/StaticBody2D at root).
	var v := Node2D.new()
	v.name = "Visual"
	add_child(v)

	var o := _editor_owner()
	if o != null:
		v.owner = o

	var old_sprite := get_node_or_null(NodePath("Sprite2D"))
	if old_sprite is Sprite2D:
		(old_sprite as Node).reparent(v)
		# Keep persistent ownership in edited scenes.
		if o != null:
			(old_sprite as Node).owner = o

	var old_body := get_node_or_null(NodePath("StaticBody2D"))
	if old_body is StaticBody2D:
		(old_body as Node).reparent(v)
		if o != null:
			(old_body as Node).owner = o

	return v


func _get_or_create_sprite() -> Sprite2D:
	var visual := _get_or_create_visual()
	var n := visual.get_node_or_null(NodePath("Sprite2D"))
	if n is Sprite2D:
		return n as Sprite2D
	var s := Sprite2D.new()
	s.name = "Sprite2D"
	visual.add_child(s)
	var o := _editor_owner()
	if o != null:
		s.owner = o
	return s


func _get_or_create_body() -> StaticBody2D:
	var visual := _get_or_create_visual()
	var n := visual.get_node_or_null(NodePath("StaticBody2D"))
	if n is StaticBody2D:
		return n as StaticBody2D
	var b := StaticBody2D.new()
	b.name = "StaticBody2D"
	visual.add_child(b)
	var o := _editor_owner()
	if o != null:
		b.owner = o
	return b


func _get_or_create_collision_shape(body: StaticBody2D) -> CollisionShape2D:
	if body == null:
		# Defensive: should never happen, but keep tool script safe.
		body = _get_or_create_body()
	var n := body.get_node_or_null(NodePath("CollisionShape2D"))
	if n is CollisionShape2D:
		return n as CollisionShape2D
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	body.add_child(cs)
	var o := _editor_owner()
	if o != null:
		cs.owner = o
	return cs


func _get_or_create_occupant() -> GridOccupantComponent:
	var n := get_node_or_null(NodePath("GridOccupantComponent"))
	if n is GridOccupantComponent:
		return n as GridOccupantComponent
	var occ := GridOccupantComponent.new()
	occ.name = "GridOccupantComponent"
	add_child(occ)
	var o := _editor_owner()
	if o != null:
		occ.owner = o
	return occ
