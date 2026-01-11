class_name ToolVisuals
extends Node2D

## Renders the equipped tool sprite as a sibling of the player under a Y-sorted entities root.
## This allows the tool to occlude correctly with world objects (trees/rocks).

@onready var tool_sprite: AnimatedSprite2D = $ToolSprite

var _player_ref: WeakRef = null
var _tool_data: ToolData = null
var _last_suffix: StringName = &"front"


func _ready() -> void:
	if tool_sprite != null:
		tool_sprite.visible = false


func attach_to_player(player: Player) -> void:
	_player_ref = weakref(player)
	_sync_to_player()


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
	_sync_to_player()
	var suffix := _direction_suffix(dir)
	_last_suffix = suffix
	tool_sprite.visible = true
	tool_sprite.position = base_offset + _tool_offset_for_suffix(suffix)
	# IMPORTANT: Do not use z_index here; it can override world occlusion (trees/rocks).
	# Let the Y-sorted entities root handle ordering against other objects.
	tool_sprite.z_index = 0
	_play_tier_dir(suffix, true, true)


func play_use(dir: Vector2, base_offset: Vector2) -> void:
	if _tool_data == null or _tool_data.tool_sprite_frames == null or tool_sprite == null:
		hide_tool()
		return
	_sync_to_player()
	var suffix := _direction_suffix(dir)
	_last_suffix = suffix
	tool_sprite.visible = true
	tool_sprite.position = base_offset + _tool_offset_for_suffix(suffix)
	tool_sprite.z_index = 0
	_play_tier_dir(suffix, false, true)


func stop_anim() -> void:
	if tool_sprite != null:
		tool_sprite.stop()


func hide_tool() -> void:
	if tool_sprite == null:
		return
	tool_sprite.visible = false
	tool_sprite.stop()


func _process(_delta: float) -> void:
	_sync_to_player()


func _sync_to_player() -> void:
	if _player_ref == null:
		return
	var p: Node = _player_ref.get_ref() as Node
	if p == null or not is_instance_valid(p):
		return
	if p is Node2D:
		global_position = (p as Node2D).global_position


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
