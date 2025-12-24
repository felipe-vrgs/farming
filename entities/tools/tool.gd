class_name HandTool
extends Node2D

@export var data: ToolData

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var swish_sprite: AnimatedSprite2D = $SwishSprite
@onready var charge_sprite: AnimatedSprite2D = $ChargeSprite

func _ready() -> void:
	swish_sprite.visible = false
	charge_sprite.visible = false

func play_swing(tool_data: ToolData, direction: Vector2) -> void:
	data = tool_data

	# Play swing sound
	if data.sound_swing:
		audio_player.stream = data.sound_swing
		audio_player.play()

	# Play swish animation
	if data.swish_type != Enums.ToolSwishType.NONE:
		var swish_name = ""
		match data.swish_type:
			Enums.ToolSwishType.SLASH:
				swish_name = "slash_effect"

		if swish_name != "":
			var dir_suffix = _get_dir_suffix(direction)
			var anim_name = StringName(str(swish_name, "_", dir_suffix))

			if swish_sprite.sprite_frames and swish_sprite.sprite_frames.has_animation(anim_name):
				swish_sprite.visible = true
				swish_sprite.play(anim_name)

func play_success() -> void:
	if data and data.sound_success:
		audio_player.stream = data.sound_success
		audio_player.play()

func play_fail() -> void:
	if data and data.sound_fail:
		audio_player.stream = data.sound_fail
		audio_player.play()

func stop_swish() -> void:
	swish_sprite.visible = false
	swish_sprite.stop()

func _get_dir_suffix(dir: Vector2) -> String:
	if abs(dir.x) >= abs(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "front" if dir.y > 0.0 else "back"
