extends Node

const POOL_SIZE = 8

var _pool: Array[AudioStreamPlayer2D] = []


func _ready() -> void:
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer2D.new()
		add_child(player)
		_pool.append(player)


func play(
	stream: AudioStream,
	position: Vector2 = Vector2.ZERO,
	pitch_range: Vector2 = Vector2(0.9, 1.1),
	volume_db: float = 0.0
) -> void:
	if stream == null:
		return

	var player = _get_available_player()

	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db

	if pitch_range != Vector2.ONE:
		player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	else:
		player.pitch_scale = 1.0

	player.play()


func _get_available_player() -> AudioStreamPlayer2D:
	for player in _pool:
		if not player.playing:
			return player

	# If no player is available, create a new one and add it to the pool
	var new_player = AudioStreamPlayer2D.new()
	add_child(new_player)
	_pool.append(new_player)
	return new_player
