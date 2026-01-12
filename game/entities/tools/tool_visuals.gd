class_name ToolVisuals
extends Node2D

## Renders the equipped tool sprite as a child of the Player.
## We keep draw-order correct relative to the player body by reordering this node
## around `CharacterVisual` / `HandsOverlay` based on facing direction.

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


func show_pose(dir: Vector2, base_offset: Vector2) -> void:
	if _tool_data == null or _tool_data.tool_sprite_frames == null or tool_sprite == null:
		hide_tool()
		return
	var suffix := _direction_suffix(dir)
	_last_suffix = suffix
	_apply_draw_order_for_suffix(suffix)
	tool_sprite.visible = true
	tool_sprite.position = base_offset + _tool_offset_for_suffix(suffix)
	_play_tier_dir(suffix, true, true)


func play_use(dir: Vector2, base_offset: Vector2) -> void:
	if _tool_data == null or _tool_data.tool_sprite_frames == null or tool_sprite == null:
		hide_tool()
		return
	var suffix := _direction_suffix(dir)
	_last_suffix = suffix
	_apply_draw_order_for_suffix(suffix)
	tool_sprite.visible = true
	tool_sprite.position = base_offset + _tool_offset_for_suffix(suffix)
	_play_tier_dir(suffix, false, true)


func stop_anim() -> void:
	if tool_sprite != null:
		tool_sprite.stop()


func hide_tool() -> void:
	if tool_sprite == null:
		return
	tool_sprite.visible = false
	tool_sprite.stop()


func _apply_draw_order_for_suffix(suffix: StringName) -> void:
	# We want:
	# - Facing up (back): tool behind the body
	# - Otherwise: tool in front of the body, but still under hands overlay if present
	var p := get_parent()
	if p == null:
		return

	var char_vis: Node = p.get_node_or_null(NodePath("CharacterVisual"))
	var hands: Node = p.get_node_or_null(NodePath("HandsOverlay"))

	if suffix == &"back":
		# Always place ToolVisuals immediately *before* CharacterVisual.
		if char_vis != null and is_instance_valid(char_vis):
			_move_before(p, self, char_vis)
		return

	# front/left/right
	if hands != null and is_instance_valid(hands):
		# Keep tool under the hands overlay (tool-use hands).
		_move_before(p, self, hands)
		return
	if char_vis != null and is_instance_valid(char_vis):
		# Otherwise, place tool just after the character body.
		_move_after(p, self, char_vis)


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
	# If node is currently after `after`, removing it will shift the target left by 1.
	if node.get_parent() == parent and node.get_index() > after.get_index():
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
