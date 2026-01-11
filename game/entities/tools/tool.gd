class_name HandTool
extends Node2D

@export var data: ToolData

var swish_type_to_name: Dictionary[Enums.ToolSwishType, StringName] = {
	Enums.ToolSwishType.SLASH: &"slash",
	Enums.ToolSwishType.SWIPE: &"swipe",
	Enums.ToolSwishType.STRIKE: &"strike",
}

var skew_ratio: float = 1
var _last_suffix: StringName = &"front"

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var swish_sprite: AnimatedSprite2D = $SwishSprite
@onready var tool_sprite: AnimatedSprite2D = $ToolSprite

@onready var marker_front: Marker2D = $Markers/MarkerFront
@onready var marker_back: Marker2D = $Markers/MarkerBack
@onready var marker_left: Marker2D = $Markers/MarkerLeft
@onready var marker_right: Marker2D = $Markers/MarkerRight

@onready var tool_marker_front: Marker2D = $ToolMarkers/Front
@onready var tool_marker_back: Marker2D = $ToolMarkers/Back
@onready var tool_marker_left: Marker2D = $ToolMarkers/Left
@onready var tool_marker_right: Marker2D = $ToolMarkers/Right


func _ready() -> void:
	swish_sprite.visible = false
	swish_sprite.position = Vector2.ZERO
	tool_sprite.visible = false


func set_held_tool(tool_data: ToolData) -> void:
	data = tool_data
	if data == null or data.tool_sprite_frames == null:
		hide_tool()
		return

	tool_sprite.sprite_frames = data.tool_sprite_frames
	tool_sprite.speed_scale = 1.0
	# Tool sprite stays hidden until actually used (charging/swing).
	hide_tool()


func show_tool_pose(direction: Vector2) -> void:
	# Show tool and snap to first frame for current direction.
	if data == null or data.tool_sprite_frames == null:
		hide_tool()
		return
	var suffix := _direction_suffix(direction)
	_last_suffix = suffix
	tool_sprite.visible = true
	_apply_tool_draw_order(suffix)
	_apply_tool_position(suffix)
	_play_tier_dir(suffix, true, true)


func hide_tool() -> void:
	if tool_sprite == null:
		return
	tool_sprite.visible = false
	tool_sprite.stop()


func play_swing(tool_data: ToolData, direction: Vector2) -> void:
	data = tool_data
	swish_sprite.speed_scale = 1.0

	# Play tool sprite animation (decoupled from player body).
	if data != null and data.tool_sprite_frames != null:
		tool_sprite.sprite_frames = data.tool_sprite_frames
		tool_sprite.visible = true
		var suffix := _direction_suffix(direction)
		_last_suffix = suffix
		_apply_tool_draw_order(suffix)
		_apply_tool_position(suffix)
		_play_tier_dir(suffix, false, true)

	# Play swing sound
	if data.sound_swing:
		audio_player.stream = data.sound_swing
		audio_player.play()

	# Play swish animation
	if data.swish_type != Enums.ToolSwishType.NONE:
		var swish_name = swish_type_to_name[data.swish_type]

		if swish_name != &"":
			if swish_sprite.sprite_frames and swish_sprite.sprite_frames.has_animation(swish_name):
				swish_sprite.visible = true

				# Reset transformations
				swish_sprite.flip_h = false
				swish_sprite.flip_v = false
				swish_sprite.rotation = 0
				swish_sprite.skew = 0.0
				swish_sprite.scale = Vector2(0.25, 0.25)

				# Positioning using Markers and custom orientation logic
				if abs(direction.x) >= abs(direction.y):
					# Horizontal
					if direction.x > 0:  # RIGHT
						swish_sprite.position = marker_right.position
						swish_sprite.flip_h = true
					else:  # LEFT
						swish_sprite.position = marker_left.position
						swish_sprite.flip_h = false
				else:
					# Vertical
					swish_sprite.scale = Vector2(0.2, 0.2)
					if direction.y > 0:  # DOWN (Front)
						swish_sprite.position = marker_front.position
						# Rotate -90 degrees so "Top" of arc is to the Right
						swish_sprite.rotation = -PI / 2
						swish_sprite.skew = skew_ratio
					else:  # UP (Back)
						swish_sprite.position = marker_back.position
						# To avoid "bottom to top", we rotate and flip
						# Rotating 90 degrees puts "Top" of arc to the Left.
						# But if it feels "backwards", we might need flip_v.
						swish_sprite.rotation = PI / 2
						swish_sprite.flip_v = true
						swish_sprite.skew = -skew_ratio

				# Ensure it starts from first frame and plays once
				swish_sprite.stop()
				swish_sprite.frame = 0
				swish_sprite.play(swish_name)


func on_success() -> void:
	if data and data.sound_success:
		audio_player.stream = data.sound_success
		audio_player.play()
	swish_sprite.speed_scale = 10.0


func on_failure() -> void:
	if data and data.sound_fail:
		audio_player.stream = data.sound_fail
		audio_player.play()
	stop_swish()


func stop_swish() -> void:
	swish_sprite.visible = false
	swish_sprite.stop()


func _direction_suffix(dir: Vector2) -> StringName:
	if abs(dir.x) >= abs(dir.y):
		return &"right" if dir.x > 0.0 else &"left"
	return &"front" if dir.y > 0.0 else &"back"


func _play_tier_dir(suffix: StringName, freeze_first_frame: bool, restart: bool) -> void:
	if data == null or data.tool_sprite_frames == null:
		return
	var tier := data.tool_sprite_tier
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


func _apply_tool_position(suffix: StringName) -> void:
	var offset := _tool_offset_for_suffix(suffix)
	match suffix:
		&"front":
			tool_sprite.position = tool_marker_front.position + offset
		&"back":
			tool_sprite.position = tool_marker_back.position + offset
		&"left":
			tool_sprite.position = tool_marker_left.position + offset
		&"right":
			tool_sprite.position = tool_marker_right.position + offset


func _tool_offset_for_suffix(suffix: StringName) -> Vector2:
	if data == null:
		return Vector2.ZERO
	match suffix:
		&"front":
			return data.tool_offset_front
		&"back":
			return data.tool_offset_back
		&"left":
			return data.tool_offset_left
		&"right":
			return data.tool_offset_right
	return Vector2.ZERO


func _apply_tool_draw_order(suffix: StringName) -> void:
	# Relative ordering within the player:
	# - Facing back: draw behind body.
	# - Otherwise: draw in front.
	tool_sprite.z_index = -1 if suffix == &"back" else 1
