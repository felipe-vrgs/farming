@tool
class_name Obstacle
extends Node2D

## Generic data-driven obstacle entity.
## - Builds visuals + collisions.
## - Registers grid occupancy via GridOccupantComponent based on the collision rectangle.

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


func _editor_owner() -> Node:
	# Ensures created nodes persist in the edited scene.
	if not Engine.is_editor_hint():
		return null
	var o := owner
	if o != null:
		return o
	var root := get_tree().edited_scene_root
	return root


func _get_or_create_sprite() -> Sprite2D:
	var n := get_node_or_null(NodePath("Sprite2D"))
	if n is Sprite2D:
		return n as Sprite2D
	var s := Sprite2D.new()
	s.name = "Sprite2D"
	add_child(s)
	var o := _editor_owner()
	if o != null:
		s.owner = o
	return s


func _get_or_create_body() -> StaticBody2D:
	var n := get_node_or_null(NodePath("StaticBody2D"))
	if n is StaticBody2D:
		return n as StaticBody2D
	var b := StaticBody2D.new()
	b.name = "StaticBody2D"
	add_child(b)
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
