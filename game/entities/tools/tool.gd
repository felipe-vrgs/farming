class_name HandTool
extends Node2D

@export var data: ToolData

var swish_type_to_name: Dictionary[Enums.ToolSwishType, StringName] = {
	Enums.ToolSwishType.SLASH: &"slash",
	Enums.ToolSwishType.SWIPE: &"swipe",
	Enums.ToolSwishType.STRIKE: &"strike",
}

var skew_ratio: float = 1

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var swish_sprite: AnimatedSprite2D = $SwishSprite
var tool_visuals: Node = null

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
	_resolve_tool_visuals_from_owner()


func set_tool_visuals(node: Node) -> void:
	tool_visuals = node
	# If we already have an equipped tool, configure visuals immediately (but keep hidden).
	if (
		tool_visuals != null
		and is_instance_valid(tool_visuals)
		and tool_visuals.has_method("configure_tool")
	):
		tool_visuals.call("configure_tool", data)


func set_held_tool(tool_data: ToolData) -> void:
	data = tool_data
	_resolve_tool_visuals_from_owner()
	# Configure external visuals (but keep hidden until use).
	if (
		tool_visuals != null
		and is_instance_valid(tool_visuals)
		and tool_visuals.has_method("configure_tool")
	):
		tool_visuals.call("configure_tool", data)
	hide_tool()


func show_tool_pose(direction: Vector2) -> void:
	# Show tool and snap to first frame for current direction (via y-sorted companion).
	_resolve_tool_visuals_from_owner()
	if tool_visuals == null or not is_instance_valid(tool_visuals):
		return
	if not tool_visuals.has_method("show_pose"):
		return
	tool_visuals.call("show_pose", direction, get_base_offset_for_dir(direction))


func hide_tool() -> void:
	if (
		tool_visuals != null
		and is_instance_valid(tool_visuals)
		and tool_visuals.has_method("hide_tool")
	):
		tool_visuals.call("hide_tool")


func play_swing(tool_data: ToolData, direction: Vector2) -> void:
	data = tool_data
	swish_sprite.speed_scale = 1.0

	# Play tool sprite animation via y-sorted companion node.
	_resolve_tool_visuals_from_owner()
	if tool_visuals != null and is_instance_valid(tool_visuals):
		if tool_visuals.has_method("configure_tool"):
			tool_visuals.call("configure_tool", data)
		if tool_visuals.has_method("play_use"):
			tool_visuals.call("play_use", direction, get_base_offset_for_dir(direction))

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
	# Failure should stop (freeze) the tool animation, not hide it.
	# The tool-use state exit will hide it as usual.
	if (
		tool_visuals != null
		and is_instance_valid(tool_visuals)
		and tool_visuals.has_method("stop_anim")
	):
		tool_visuals.call("stop_anim")


func stop_swish() -> void:
	swish_sprite.visible = false
	swish_sprite.stop()


func _direction_suffix(dir: Vector2) -> StringName:
	if abs(dir.x) >= abs(dir.y):
		return &"right" if dir.x > 0.0 else &"left"
	return &"front" if dir.y > 0.0 else &"back"


func get_base_offset_for_dir(dir: Vector2) -> Vector2:
	# Base attach point in *global* coordinates, using ToolMarkers.
	# ToolVisuals uses global_position so it can be parented anywhere (e.g. under CharacterVisual).
	var suffix := _direction_suffix(dir)
	match suffix:
		&"front":
			return tool_marker_front.global_position
		&"back":
			return tool_marker_back.global_position
		&"left":
			return tool_marker_left.global_position
		&"right":
			return tool_marker_right.global_position
	return global_position


func _resolve_tool_visuals_from_owner() -> void:
	# Self-healing binding: in some scene setups/hot-reloads the Player may not have
	# called `set_tool_visuals()` yet. If this reference is missing, the tool sprite
	# never renders (but swish/sound still plays), so resolve it here.
	if tool_visuals != null and is_instance_valid(tool_visuals):
		return

	var candidates: Array[NodePath] = [
		NodePath("CharacterVisual/ToolLayer/ToolVisuals"),
		NodePath("CharacterVisual/ToolVisuals"),
		NodePath("ToolVisuals"),
	]

	# Prefer `owner` (scene root for this node), but also walk parents as a fallback.
	var n: Node = owner if (owner != null and is_instance_valid(owner)) else self
	for _i in range(12):
		if n == null:
			break
		for p in candidates:
			var tv := n.get_node_or_null(p)
			if tv != null and is_instance_valid(tv):
				set_tool_visuals(tv)
				return
		n = n.get_parent()
