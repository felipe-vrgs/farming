class_name FootstepsComponent
extends Node

const FOOTSTEP_INTERVAL: float = 0.35

@export var audio_player: AudioStreamPlayer2D

# Preload footstep sounds
var footsteps: Array[AudioStream] = [
	preload("res://assets/sounds/player/footstep00.ogg"),
	preload("res://assets/sounds/player/footstep01.ogg"),
	preload("res://assets/sounds/player/footstep02.ogg"),
	preload("res://assets/sounds/player/footstep03.ogg"),
	preload("res://assets/sounds/player/footstep04.ogg"),
	preload("res://assets/sounds/player/footstep05.ogg"),
	preload("res://assets/sounds/player/footstep06.ogg"),
	preload("res://assets/sounds/player/footstep07.ogg"),
	preload("res://assets/sounds/player/footstep08.ogg"),
	preload("res://assets/sounds/player/footstep09.ogg"),
]
var _footstep_timer: float = 0.0


func clear_timer() -> void:
	_footstep_timer = 0.0


func play_footstep(delta: float) -> void:
	if audio_player == null:
		return

	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer = FOOTSTEP_INTERVAL
		var idx = randi() % footsteps.size()
		audio_player.stream = footsteps[idx]
		audio_player.play()
