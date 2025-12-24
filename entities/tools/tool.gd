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
@onready var charge_sprite: AnimatedSprite2D = $ChargeSprite

@onready var marker_front: Marker2D = $Markers/MarkerFront
@onready var marker_back: Marker2D = $Markers/MarkerBack
@onready var marker_left: Marker2D = $Markers/MarkerLeft
@onready var marker_right: Marker2D = $Markers/MarkerRight


func _ready() -> void:
	swish_sprite.visible = false
	charge_sprite.visible = false
	swish_sprite.position = Vector2.ZERO

func play_swing(tool_data: ToolData, direction: Vector2) -> void:
	data = tool_data
	swish_sprite.speed_scale = 1.0

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
					if direction.x > 0: # RIGHT
						swish_sprite.position = marker_right.position
						swish_sprite.flip_h = true
					else: # LEFT
						swish_sprite.position = marker_left.position
						swish_sprite.flip_h = false
				else:
					# Vertical
					swish_sprite.scale = Vector2(0.2, 0.2)
					if direction.y > 0: # DOWN (Front)
						swish_sprite.position = marker_front.position
						# Rotate -90 degrees so "Top" of arc is to the Right
						swish_sprite.rotation = -PI/2
						swish_sprite.skew = skew_ratio
					else: # UP (Back)
						swish_sprite.position = marker_back.position
						# To avoid "bottom to top", we rotate and flip
						# Rotating 90 degrees puts "Top" of arc to the Left.
						# But if it feels "backwards", we might need flip_v.
						swish_sprite.rotation = PI/2
						swish_sprite.flip_v = true
						swish_sprite.skew = -skew_ratio

				# Ensure it starts from first frame and plays once
				swish_sprite.stop()
				swish_sprite.frame = 0
				swish_sprite.play(swish_name)

func play_success() -> void:
	if data and data.sound_success:
		audio_player.stream = data.sound_success
		audio_player.play()
	swish_sprite.speed_scale = 10.0

func play_fail() -> void:
	if data and data.sound_fail:
		audio_player.stream = data.sound_fail
		audio_player.play()
	stop_swish()

func stop_swish() -> void:
	swish_sprite.visible = false
	swish_sprite.stop()
