@tool
extends Node2D

## Generic data-driven obstacle entity.
## - Builds visuals + collisions.
## - Registers grid occupancy via GridOccupantComponent based on the collision rectangle.

@export var data: ObstacleData:
	set(v):
		data = v
		_apply_data()


func _ready() -> void:
	_apply_data()


func _apply_data() -> void:
	if data == null:
		return

	var sprite := _get_or_create_sprite()
	sprite.texture = data.texture
	sprite.centered = data.centered
	sprite.position = data.sprite_offset

	var body := _get_or_create_body()
	body.collision_layer = data.collision_layer
	body.collision_mask = data.collision_mask

	var cs := _get_or_create_collision_shape(body)
	cs.position = data.collision_offset
	var rect := cs.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		cs.shape = rect
	rect.size = data.collision_size

	var occ := _get_or_create_occupant()
	occ.entity_type = data.entity_type
	occ.collision_shape = cs


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
