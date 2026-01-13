class_name ToolVisuals
extends Node2D

## Renders the equipped tool sprite as part of the character's layered visuals.
## Intended scene placement: `Player/CharacterVisual/ToolLayer/ToolVisuals`
## (where `ToolLayer` sits between `Shirt` and `Hands`), so the hands always draw
## above the tool in left/right/front poses.
## Layer exceptions (during use) are handled by reordering `ToolLayer` relative to
## other CharacterVisual children (no z-index hacks; world Y-depth stays intact).

@onready var tool_sprite: AnimatedSprite2D = $ToolSprite

var _tool_data: ToolData = null
var _last_suffix: StringName = &"front"


func _ready() -> void:
	if tool_sprite != null:
		tool_sprite.visible = false


func configure_tool(data: ToolData) -> void:
	_tool_data = data
	if tool_sprite == null:
		return
	if _tool_data == null or _tool_data.tool_sprite_frames == null:
		hide_tool()
		return
	tool_sprite.sprite_frames = _tool_data.tool_sprite_frames
	tool_sprite.speed_scale = 1.0
	hide_tool()


func show_pose(dir: Vector2, base_offset_global: Vector2) -> void:
	if _tool_data == null or _tool_data.tool_sprite_frames == null or tool_sprite == null:
		hide_tool()
		return
	var suffix := _direction_suffix(dir)
	_last_suffix = suffix
	_apply_draw_order_for_suffix(suffix, false)
	tool_sprite.visible = true
	tool_sprite.global_position = base_offset_global + _tool_offset_for_suffix(suffix)
	_play_tier_dir(suffix, true, true)


func play_use(dir: Vector2, base_offset_global: Vector2) -> void:
	if _tool_data == null or _tool_data.tool_sprite_frames == null or tool_sprite == null:
		hide_tool()
		return
	var suffix := _direction_suffix(dir)
	_last_suffix = suffix
	_apply_draw_order_for_suffix(suffix, true)
	tool_sprite.visible = true
	tool_sprite.global_position = base_offset_global + _tool_offset_for_suffix(suffix)
	_play_tier_dir(suffix, false, true)


func stop_anim() -> void:
	if tool_sprite != null:
		tool_sprite.stop()


func hide_tool() -> void:
	if tool_sprite == null:
		return
	tool_sprite.visible = false
	tool_sprite.stop()


func _apply_draw_order_for_suffix(suffix: StringName, is_using: bool) -> void:
	# Keep Y-depth behavior (world sorting) intact; only adjust *layering within the character*
	# by reordering `CharacterVisual/ToolLayer` relative to the other CharacterVisual children.
	#
	# Scene expectation:
	# Player
	#   CharacterVisual
	#     ... Shirt
	#     ToolLayer
	#       ToolVisuals (this)
	#     Hands
	#     Face
	#     Hair
	var tool_layer := get_parent()
	if tool_layer == null:
		return
	var char_vis := tool_layer.get_parent()
	if char_vis == null:
		return

	var legs: Node = char_vis.get_node_or_null(NodePath("Legs"))
	var torso: Node = char_vis.get_node_or_null(NodePath("Torso"))
	var pants: Node = char_vis.get_node_or_null(NodePath("Pants"))
	var shirt: Node = char_vis.get_node_or_null(NodePath("Shirt"))
	var hands: Node = char_vis.get_node_or_null(NodePath("Hands"))
	var hair: Node = char_vis.get_node_or_null(NodePath("Hair"))

	# "Default" placement for tool when visible: after clothing/body, before hands.
	# This prevents the tool from getting stuck behind the whole body after a previous
	# `back` use (which moves ToolLayer to index 0).
	var anchor: Node = null
	if shirt != null and is_instance_valid(shirt):
		anchor = shirt
	elif torso != null and is_instance_valid(torso):
		anchor = torso
	elif pants != null and is_instance_valid(pants):
		anchor = pants
	elif legs != null and is_instance_valid(legs):
		anchor = legs

	# Default (idle/charging pose): keep tool under hands.
	if not is_using:
		if anchor != null and is_instance_valid(anchor):
			_move_after(char_vis, tool_layer, anchor)
		if hands != null and is_instance_valid(hands):
			_move_before(char_vis, tool_layer, hands)
		return

	# Using tool:
	# - Facing away from camera ("back"): tool behind the whole player.
	# - Facing towards camera ("front"): tool above everything.
	# - Left/Right: keep tool *under* the hands (hand overlaps the grip).
	if suffix == &"back":
		# Behind everything: move to the very front of CharacterVisual children.
		if legs != null and is_instance_valid(legs):
			_move_before(char_vis, tool_layer, legs)
		else:
			char_vis.move_child(tool_layer, 0)
		return

	if suffix == &"front":
		# Above everything: move to the very end of CharacterVisual children.
		if hair != null and is_instance_valid(hair):
			_move_after(char_vis, tool_layer, hair)
		else:
			char_vis.move_child(tool_layer, max(0, char_vis.get_child_count() - 1))
		return

	# left/right
	if hands != null and is_instance_valid(hands):
		if anchor != null and is_instance_valid(anchor):
			_move_after(char_vis, tool_layer, anchor)
		_move_before(char_vis, tool_layer, hands)


func _move_before(parent: Node, node: Node, before: Node) -> void:
	if parent == null or node == null or before == null:
		return
	if node == before:
		return
	var idx := before.get_index()
	# If node is currently before `before`, removing it will shift `before` left by 1.
	if node.get_parent() == parent and node.get_index() < idx:
		idx -= 1
	parent.move_child(node, max(0, idx))


func _move_after(parent: Node, node: Node, after: Node) -> void:
	if parent == null or node == null or after == null:
		return
	if node == after:
		return
	var idx := after.get_index() + 1
	# If node is currently before `after`, removing it will shift the target left by 1.
	if node.get_parent() == parent and node.get_index() < after.get_index():
		idx -= 1
	parent.move_child(node, clampi(idx, 0, max(0, parent.get_child_count() - 1)))


func _direction_suffix(dir: Vector2) -> StringName:
	if abs(dir.x) >= abs(dir.y):
		return &"right" if dir.x > 0.0 else &"left"
	return &"front" if dir.y > 0.0 else &"back"


func _play_tier_dir(suffix: StringName, freeze_first_frame: bool, restart: bool) -> void:
	if _tool_data == null or _tool_data.tool_sprite_frames == null or tool_sprite == null:
		return
	var tier := _tool_data.tool_sprite_tier
	if String(tier).is_empty():
		tier = &"iron"
	var anim := StringName(str(tier, "_", suffix))
	if not tool_sprite.sprite_frames.has_animation(anim):
		return
	if restart:
		tool_sprite.stop()
	tool_sprite.play(anim)
	if freeze_first_frame:
		tool_sprite.stop()
		tool_sprite.frame = 0


func _tool_offset_for_suffix(suffix: StringName) -> Vector2:
	if _tool_data == null:
		return Vector2.ZERO
	match suffix:
		&"front":
			return _tool_data.tool_offset_front
		&"back":
			return _tool_data.tool_offset_back
		&"left":
			return _tool_data.tool_offset_left
		&"right":
			return _tool_data.tool_offset_right
	return Vector2.ZERO
