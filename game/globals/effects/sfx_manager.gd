extends Node

const POOL_SIZE = 8

const BUS_MASTER := &"Master"
const BUS_SFX := &"SFX"
const BUS_MUSIC := &"Music"
const BUS_AMBIENCE := &"Ambience"

## Menu audio defaults (in-game audio is defined exclusively by LevelRoot exports).
const MENU_MUSIC_PATH := "res://assets/music/chill_lofi_loop.ogg"
const MENU_AMBIENCE_PATH := ""  # optional

var _pool: Array[AudioStreamPlayer2D] = []

var _music_player: AudioStreamPlayer = null
var _ambience_player: AudioStreamPlayer = null

var _music_tween: Tween = null
var _ambience_tween: Tween = null

var _music_target_volume_db: float = -20.0
var _ambience_target_volume_db: float = -20.0


func _ready() -> void:
	_ensure_default_buses()

	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer2D.new()
		player.bus = BUS_SFX
		add_child(player)
		_pool.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = BUS_AMBIENCE
	_ambience_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambience_player)

	# Bind to level changes to auto-switch tracks.
	if (
		is_instance_valid(EventBus)
		and not EventBus.active_level_changed.is_connected(_on_active_level_changed)
	):
		EventBus.active_level_changed.connect(_on_active_level_changed)

	# Bind to game state changes (menu <-> in-game), so audio updates even when
	# the level id doesn't change (e.g. boot to MENU).
	call_deferred("_try_connect_game_flow")

	# Best-effort boot: start something immediately.
	call_deferred("_refresh_audio_for_context")


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


func play_music(stream: AudioStream, fade_seconds: float = 0.75, volume_db: float = -8.0) -> void:
	_music_target_volume_db = volume_db
	_transition_stream(_music_player, stream, _music_target_volume_db, fade_seconds, true)


func play_ambience(
	stream: AudioStream, fade_seconds: float = 0.75, volume_db: float = -20.0
) -> void:
	_ambience_target_volume_db = volume_db
	_transition_stream(_ambience_player, stream, _ambience_target_volume_db, fade_seconds, true)


func fade_out_music(duration_seconds: float = 0.6) -> void:
	_fade_player_to(_music_player, -80.0, duration_seconds)


func fade_in_music(duration_seconds: float = 0.6) -> void:
	_fade_player_to(_music_player, _music_target_volume_db, duration_seconds)


func _get_available_player() -> AudioStreamPlayer2D:
	for player in _pool:
		if not player.playing:
			return player

	# If no player is available, create a new one and add it to the pool
	var new_player = AudioStreamPlayer2D.new()
	new_player.bus = BUS_SFX
	add_child(new_player)
	_pool.append(new_player)
	return new_player


func _bootstrap_default_audio() -> void:
	# Back-compat: older code paths may still call this.
	_refresh_audio_for_context()


func _on_active_level_changed(_prev: int, _next: int) -> void:
	_refresh_audio_for_context()


func _apply_level_audio_from_level_root() -> void:
	# In-game: LevelRoot is the ONLY source of audio. If nothing is assigned, stop.
	var lr := _get_active_level_root()
	if lr == null:
		_stop_music(0.5)
		_stop_ambience(0.5)
		return

	var level_music: AudioStream = null
	var level_ambience: AudioStream = null

	# Prefer explicit getters if present.
	if lr.has_method("get_music_stream"):
		var v: Variant = lr.call("get_music_stream")
		if v is AudioStream:
			level_music = v as AudioStream
	else:
		var v2: Variant = lr.get("music_stream")
		if v2 is AudioStream:
			level_music = v2 as AudioStream

	if lr.has_method("get_ambience_stream"):
		var a: Variant = lr.call("get_ambience_stream")
		if a is AudioStream:
			level_ambience = a as AudioStream
	else:
		var a2: Variant = lr.get("ambience_stream")
		if a2 is AudioStream:
			level_ambience = a2 as AudioStream

	if level_music != null:
		play_music(level_music, 1.0, _music_target_volume_db)
	else:
		_stop_music(0.5)

	if level_ambience != null:
		play_ambience(level_ambience, 1.0, _ambience_target_volume_db)
	else:
		_stop_ambience(0.5)


func _apply_menu_audio_defaults() -> void:
	var music_stream := _load_audio_stream(MENU_MUSIC_PATH)
	if music_stream != null:
		play_music(music_stream, 1.0, _music_target_volume_db)
	else:
		_stop_music(0.5)

	var ambience_stream := _load_audio_stream(MENU_AMBIENCE_PATH)
	if ambience_stream != null:
		play_ambience(ambience_stream, 1.0, _ambience_target_volume_db)
	else:
		_stop_ambience(0.5)


func _refresh_audio_for_context() -> void:
	# Menu uses defaults; in-game uses LevelRoot exports exclusively.
	if _is_menu_state():
		_apply_menu_audio_defaults()
	else:
		_apply_level_audio_from_level_root()


func _get_active_level_root() -> Node:
	if not is_instance_valid(Runtime) or not Runtime.has_method("get_active_level_root"):
		return null
	var lr: Variant = Runtime.call("get_active_level_root")
	return lr as Node


func _is_menu_state() -> bool:
	# Mirror DayNightManager behavior.
	if not is_instance_valid(Runtime) or Runtime.game_flow == null:
		# On boot, we are effectively in menu context.
		return true
	var gf: Node = Runtime.game_flow
	var state_v: Variant = gf.get("state")
	if state_v is StringName:
		var st: StringName = state_v
		return st == GameStateNames.MENU or st == GameStateNames.BOOT
	return false


func _try_connect_game_flow() -> void:
	if not is_instance_valid(Runtime) or Runtime.game_flow == null:
		return
	var gf: Node = Runtime.game_flow
	if gf.has_signal("state_changed"):
		var cb := Callable(self, "_on_game_state_changed")
		if not gf.is_connected("state_changed", cb):
			gf.connect("state_changed", cb)


func _on_game_state_changed(_prev: StringName, _next: StringName) -> void:
	_refresh_audio_for_context()


func _load_audio_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	var res: Resource = load(path)
	if res is AudioStream:
		return res as AudioStream
	return null


func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		var sample_count := int(round(wav.get_length() * float(wav.mix_rate)))
		if sample_count > 0:
			wav.loop_end = sample_count


func _stop_music(fade_seconds: float = 0.5) -> void:
	_stop_player(_music_player, fade_seconds)


func _stop_ambience(fade_seconds: float = 0.5) -> void:
	_stop_player(_ambience_player, fade_seconds)


func _stop_player(player: AudioStreamPlayer, fade_seconds: float) -> void:
	if player == null:
		return
	var tween_ref: Tween = _music_tween if player == _music_player else _ambience_tween
	if tween_ref != null and is_instance_valid(tween_ref):
		tween_ref.kill()

	if not player.playing:
		player.stream = null
		return

	if fade_seconds <= 0.0:
		player.stop()
		player.stream = null
		return

	tween_ref = create_tween()
	tween_ref.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_ref.tween_property(player, "volume_db", -80.0, fade_seconds)
	tween_ref.tween_callback(
		func() -> void:
			player.stop()
			player.stream = null
	)

	if player == _music_player:
		_music_tween = tween_ref
	else:
		_ambience_tween = tween_ref


func _transition_stream(
	player: AudioStreamPlayer,
	stream: AudioStream,
	target_volume_db: float,
	fade_seconds: float,
	start_from_silence: bool
) -> void:
	if player == null or stream == null:
		return
	if player.playing and player.stream == stream:
		return

	var tween_ref: Tween = _music_tween if player == _music_player else _ambience_tween
	if tween_ref != null and is_instance_valid(tween_ref):
		tween_ref.kill()

	if fade_seconds <= 0.0:
		player.stream = stream
		_enable_loop(stream)
		player.volume_db = target_volume_db
		player.play()
		return

	var half := maxf(0.0, fade_seconds * 0.5)
	tween_ref = create_tween()
	tween_ref.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if player.playing and player.stream != null:
		tween_ref.tween_property(player, "volume_db", -80.0, half)
		tween_ref.tween_callback(
			func() -> void:
				player.stop()
				player.stream = stream
				_enable_loop(stream)
				player.volume_db = -80.0 if start_from_silence else target_volume_db
				player.play()
		)
		tween_ref.tween_property(player, "volume_db", target_volume_db, half)
	else:
		player.stream = stream
		_enable_loop(stream)
		player.volume_db = -80.0 if start_from_silence else target_volume_db
		player.play()
		tween_ref.tween_property(player, "volume_db", target_volume_db, fade_seconds)

	if player == _music_player:
		_music_tween = tween_ref
	else:
		_ambience_tween = tween_ref


func _fade_player_to(player: AudioStreamPlayer, target_db: float, duration: float) -> void:
	if player == null:
		return

	var tween_ref: Tween = _music_tween if player == _music_player else _ambience_tween
	if tween_ref != null and is_instance_valid(tween_ref):
		tween_ref.kill()

	if duration <= 0.0:
		player.volume_db = target_db
		return

	tween_ref = create_tween()
	tween_ref.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_ref.tween_property(player, "volume_db", target_db, duration)

	if player == _music_player:
		_music_tween = tween_ref
	else:
		_ambience_tween = tween_ref


func _ensure_default_buses() -> void:
	# If the project's default bus layout is missing/misconfigured, ensure the
	# expected buses exist so runtime audio doesn't break (useful for headless tests too).
	_ensure_bus(BUS_MUSIC, BUS_MASTER)
	_ensure_bus(BUS_SFX, BUS_MASTER)
	_ensure_bus(BUS_AMBIENCE, BUS_SFX)


func _ensure_bus(bus_name: StringName, send_to: StringName) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus(AudioServer.bus_count)
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send_to)
