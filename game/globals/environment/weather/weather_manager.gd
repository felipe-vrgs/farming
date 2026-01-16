extends Node

const FARM_LEVEL_ID := int(Enums.Levels.ISLAND)
const BUS_AMBIENCE := &"Ambience"

@export var weather_layer_scene: PackedScene = preload(
	"res://game/globals/environment/weather/weather_layer.tscn"
)
@export var rain_texture: Texture2D = preload("res://assets/particles/rain/rain.tres")

@export_range(0.0, 1.0, 0.01) var rain_intensity: float = 1.0
@export_range(0.0, 1.0, 0.01) var wind_strength: float = 0.4
@export var wind_dir: Vector2 = Vector2(0.2, 0.1)

@export_group("Audio")
@export
var rain_ambience_stream: AudioStream = preload("res://assets/ambience/rain_ambience_loop.ogg")
@export var rain_ambience_volume_db: float = -18.0
@export var rain_ambience_volume_db_interior: float = -22.0
@export var rain_ambience_fade_seconds: float = 0.4
@export var thunder_streams: Array[AudioStream] = [
	preload("res://assets/sounds/weather/thunder_bidgee_thunder.ogg"),
	preload("res://assets/sounds/weather/thunder_rain_and_thunder_pd.ogg"),
	preload("res://assets/sounds/weather/thunder_and_rain_on_veranda_pd.ogg"),
]
@export_range(0.0, 1.0, 0.01) var thunder_strength: float = 0.85
@export var thunder_interval_range: Vector2 = Vector2(6.0, 14.0)
@export var thunder_delay_range: Vector2 = Vector2(0.6, 2.1)
@export var thunder_volume_db: float = -8.0
@export var thunder_enabled: bool = true

@export_group("Rain Watering")
@export var auto_wet_enabled: bool = true
@export var wet_interval_range: Vector2 = Vector2(0.4, 0.6)
@export var wet_visible_only: bool = true

@export_group("Lighting")
@export_range(0.0, 1.0, 0.01) var rain_day_strength: float = 0.5

@export_group("Splashes")
@export var splash_enabled: bool = true
@export var splash_interval_range: Vector2 = Vector2(0.15, 0.35)
@export_range(1, 8, 1) var splash_per_tick: int = 4
@export var splash_z_index: int = 10

var _layer: WeatherLayer = null
var _rain_player: AudioStreamPlayer = null
var _rain_tween: Tween = null
var _thunder_timer: Timer = null
var _wet_timer: Timer = null
var _splash_timer: Timer = null

var _raining: bool = false
var _active_context: bool = false
var _wet_per_tick: int = 3


func _is_test_mode() -> bool:
	return OS.get_environment("FARMING_TEST_MODE") == "1"


func _ready() -> void:
	if _is_test_mode():
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_init_layer")
	_init_audio()
	_init_timers()
	_try_connect_events()


func _process(_delta: float) -> void:
	var should_be_active := _is_active_context()
	if should_be_active != _active_context:
		_active_context = should_be_active
		if not _active_context:
			_stop_weather()
		else:
			_apply_weather_state()


func set_raining(enabled: bool, intensity: float = -1.0) -> void:
	var was_raining := _raining
	_raining = enabled
	if intensity >= 0.0:
		rain_intensity = clampf(intensity, 0.0, 1.0)
	if enabled and not was_raining:
		_apply_offline_rain_wet()
	_apply_weather_state()


func is_raining() -> bool:
	return _raining


func write_save_state(gs: GameSave) -> void:
	if gs == null:
		return
	gs.weather_is_raining = _raining
	gs.weather_rain_intensity = rain_intensity
	gs.weather_wind_dir = wind_dir
	gs.weather_wind_strength = wind_strength


func apply_save_state(gs: GameSave) -> void:
	if gs == null:
		return
	var is_raining_v := bool(gs.weather_is_raining)
	var intensity_v := float(gs.weather_rain_intensity)
	var wind_dir_v := gs.weather_wind_dir
	var wind_strength_v := float(gs.weather_wind_strength)
	if wind_dir_v is Vector2:
		wind_dir = wind_dir_v
	wind_strength = wind_strength_v
	set_raining(is_raining_v, intensity_v)


func _init_layer() -> void:
	if _layer != null and is_instance_valid(_layer):
		return
	if weather_layer_scene == null:
		return
	var inst := weather_layer_scene.instantiate()
	_layer = inst as WeatherLayer
	if _layer == null:
		inst.queue_free()
		return
	if rain_texture != null:
		_layer.rain_texture = rain_texture
	get_tree().root.add_child(_layer)
	_layer.visible = false


func _init_audio() -> void:
	_rain_player = AudioStreamPlayer.new()
	_rain_player.name = "WeatherRainAmbience"
	_rain_player.bus = BUS_AMBIENCE
	_rain_player.volume_db = rain_ambience_volume_db
	_rain_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_rain_player)


func _init_timers() -> void:
	_thunder_timer = Timer.new()
	_thunder_timer.one_shot = true
	_thunder_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_thunder_timer)
	_thunder_timer.timeout.connect(_on_thunder_timeout)

	_wet_timer = Timer.new()
	_wet_timer.one_shot = true
	_wet_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_wet_timer)
	_wet_timer.timeout.connect(_on_wet_timeout)

	_splash_timer = Timer.new()
	_splash_timer.one_shot = true
	_splash_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_splash_timer)
	_splash_timer.timeout.connect(_on_splash_timeout)


func _apply_weather_state() -> void:
	if not _active_context:
		return
	if _layer == null or not is_instance_valid(_layer):
		_init_layer()
	if _layer == null or not is_instance_valid(_layer):
		return

	_layer.visible = _raining
	if _raining:
		_layer.set_rain_enabled(true, rain_intensity)
		_layer.set_wind(wind_dir, wind_strength)
		_set_rain_audio_volume(rain_ambience_volume_db)
		_apply_rain_lighting(true)
		_schedule_thunder()
		_schedule_wet()
		_schedule_splash()
	else:
		_layer.set_rain_enabled(false, 0.0)
		_stop_rain_audio()
		_apply_rain_lighting(false)
		_cancel_thunder()
		_cancel_wet()
		_cancel_splash()


func _stop_weather() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.visible = false
		_layer.set_rain_enabled(false, 0.0)
	_cancel_thunder()
	_cancel_wet()
	_cancel_splash()
	if _raining:
		_set_rain_audio_volume(rain_ambience_volume_db_interior)
		_apply_rain_lighting(true)
	else:
		_stop_rain_audio()
		_apply_rain_lighting(false)


func _start_rain_audio() -> void:
	if _rain_player == null or rain_ambience_stream == null:
		return
	if _rain_player.stream != rain_ambience_stream:
		_rain_player.stream = rain_ambience_stream
	_rain_player.volume_db = -80.0
	if not _rain_player.playing:
		_rain_player.play()
	_fade_rain_to(rain_ambience_volume_db, rain_ambience_fade_seconds)


func _set_rain_audio_volume(target_db: float) -> void:
	if _rain_player == null or rain_ambience_stream == null:
		return
	if _rain_player.stream != rain_ambience_stream:
		_rain_player.stream = rain_ambience_stream
	if not _rain_player.playing:
		_rain_player.volume_db = -80.0
		_rain_player.play()
	_fade_rain_to(target_db, rain_ambience_fade_seconds)


func _stop_rain_audio() -> void:
	if _rain_player == null:
		return
	_fade_rain_to(-80.0, rain_ambience_fade_seconds)


func _fade_rain_to(target_db: float, duration: float) -> void:
	if _rain_player == null:
		return
	if _rain_tween != null and is_instance_valid(_rain_tween):
		_rain_tween.kill()
	if duration <= 0.0:
		_rain_player.volume_db = target_db
		if target_db <= -79.0:
			_rain_player.stop()
		return
	_rain_tween = create_tween()
	_rain_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_rain_tween.tween_property(_rain_player, "volume_db", target_db, duration)
	_rain_tween.tween_callback(
		func() -> void:
			if target_db <= -79.0 and _rain_player != null and is_instance_valid(_rain_player):
				_rain_player.stop()
	)


func _schedule_thunder() -> void:
	if not thunder_enabled or thunder_streams.is_empty() or _thunder_timer == null:
		return
	if _thunder_timer.is_stopped():
		_thunder_timer.start(_rand_range(thunder_interval_range))


func _cancel_thunder() -> void:
	if _thunder_timer != null:
		_thunder_timer.stop()


func _on_thunder_timeout() -> void:
	if not _raining or not _active_context:
		return
	if _layer != null and is_instance_valid(_layer):
		_layer.flash_lightning(thunder_strength)
	var delay := _rand_range(thunder_delay_range)
	get_tree().create_timer(delay).timeout.connect(
		func() -> void:
			if _raining and _active_context:
				_play_thunder()
				_schedule_thunder()
	)


func _play_thunder() -> void:
	if thunder_streams.is_empty():
		return
	var stream := thunder_streams[randi() % thunder_streams.size()]
	if stream == null:
		return
	var pos := _get_player_pos()
	if SFXManager != null:
		SFXManager.play_effect(stream, pos, Vector2.ONE, thunder_volume_db)


func _schedule_wet() -> void:
	if not auto_wet_enabled or _wet_timer == null:
		return
	if _wet_timer.is_stopped():
		_wet_timer.start(_rand_range(wet_interval_range))


func _cancel_wet() -> void:
	if _wet_timer != null:
		_wet_timer.stop()


func _on_wet_timeout() -> void:
	if not _raining or not _active_context:
		return
	_apply_rain_wet()
	_schedule_wet()


func _schedule_splash() -> void:
	if not splash_enabled or _splash_timer == null:
		return
	if _splash_timer.is_stopped():
		_splash_timer.start(_rand_range(splash_interval_range))


func _cancel_splash() -> void:
	if _splash_timer != null:
		_splash_timer.stop()


func _on_splash_timeout() -> void:
	if not _raining or not _active_context:
		return
	_spawn_rain_splashes()
	_schedule_splash()


func _apply_rain_wet() -> void:
	if WorldGrid == null or WorldGrid.terrain_state == null:
		return
	if not WorldGrid.ensure_initialized():
		return
	var terrain := WorldGrid.terrain_state
	var dry_soil: Array[Vector2i] = []
	if wet_visible_only:
		_collect_visible_dry_soil(terrain, dry_soil)
	else:
		var cells := terrain.list_terrain_cells_for_simulation()
		for cell in cells:
			if terrain.get_terrain_at(cell) == GridCellData.TerrainType.SOIL:
				dry_soil.append(cell)
	if dry_soil.is_empty():
		return
	var count := mini(dry_soil.size(), maxi(1, _wet_per_tick))
	for i in range(count):
		var idx := randi() % dry_soil.size()
		var cell := dry_soil[idx]
		dry_soil.remove_at(idx)
		WorldGrid.set_wet(cell)


func _collect_visible_dry_soil(terrain: TerrainState, out: Array[Vector2i]) -> void:
	var rect := _get_viewport_world_rect()
	if rect.size == Vector2.ZERO:
		return
	if WorldGrid.tile_map == null or not WorldGrid.tile_map.ensure_initialized():
		return
	var attempts := maxi(12, _wet_per_tick * 8)
	for i in range(attempts):
		var pos := Vector2(
			randf_range(rect.position.x, rect.position.x + rect.size.x),
			randf_range(rect.position.y, rect.position.y + rect.size.y)
		)
		var cell := WorldGrid.tile_map.global_to_cell(pos)
		if terrain.get_terrain_at(cell) == GridCellData.TerrainType.SOIL and not out.has(cell):
			out.append(cell)
			if out.size() >= _wet_per_tick:
				return


func _apply_offline_rain_wet() -> void:
	if Runtime == null:
		return
	var sm: Node = Runtime.get("save_manager")
	if sm == null or not sm.has_method("list_session_level_ids"):
		return
	if not sm.has_method("load_session_level_save") or not sm.has_method("save_session_level_save"):
		return
	var active_id := -1
	if Runtime.has_method("get_active_level_id"):
		active_id = int(Runtime.call("get_active_level_id"))
	for level_id in sm.call("list_session_level_ids"):
		if int(level_id) == active_id:
			continue
		var ls: LevelSave = sm.call("load_session_level_save", level_id)
		if ls == null:
			continue
		var changed := false
		for cs in ls.cells:
			if cs == null:
				continue
			if int(cs.terrain_id) == int(GridCellData.TerrainType.SOIL):
				cs.terrain_id = int(GridCellData.TerrainType.SOIL_WET)
				changed = true
		if changed:
			sm.call("save_session_level_save", ls)


func _try_connect_events() -> void:
	if EventBus == null:
		return
	var cb := Callable(self, "_on_active_level_changed")
	if (
		EventBus.has_signal("active_level_changed")
		and not EventBus.is_connected("active_level_changed", cb)
	):
		EventBus.connect("active_level_changed", cb)


func _on_active_level_changed(_prev: Enums.Levels, _next: Enums.Levels) -> void:
	if _raining:
		_apply_offline_rain_wet()


func _spawn_rain_splashes() -> void:
	if not splash_enabled:
		return
	if VFXManager == null or not VFXManager.has_method("spawn_water_splash_at"):
		return
	var rect := _get_viewport_world_rect()
	if rect.size == Vector2.ZERO:
		return
	var count := maxi(1, splash_per_tick)
	for i in range(count):
		var pos := Vector2(
			randf_range(rect.position.x, rect.position.x + rect.size.x),
			randf_range(rect.position.y, rect.position.y + rect.size.y)
		)
		VFXManager.spawn_water_splash_at(pos, splash_z_index)


func _apply_rain_lighting(enabled: bool) -> void:
	if DayNightManager == null:
		return
	if enabled:
		DayNightManager.set_rain_mode(true, rain_day_strength)
	else:
		DayNightManager.set_rain_mode(false)


func _get_player_pos() -> Vector2:
	if Runtime != null and Runtime.has_method("find_agent_by_id"):
		var p: Variant = Runtime.call("find_agent_by_id", &"player")
		if p is Node2D:
			return (p as Node2D).global_position
	return Vector2.ZERO


func _get_viewport_world_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var screen_size := vp.get_visible_rect().size
	var cam := _get_camera()
	var center := cam.global_position if cam != null else Vector2.ZERO
	var zoom := cam.zoom if cam != null else Vector2.ONE
	var world_size := Vector2(
		screen_size.x / maxf(zoom.x, 0.001), screen_size.y / maxf(zoom.y, 0.001)
	)
	var half := world_size * 0.5
	return Rect2(center - half, world_size)


func _get_camera() -> Camera2D:
	var vp := get_viewport()
	if vp == null:
		return null
	var cam := vp.get_camera_2d()
	return cam


func _is_active_context() -> bool:
	if Runtime == null or not Runtime.has_method("get_active_level_id"):
		return false
	var level_id := int(Runtime.call("get_active_level_id"))
	if level_id != FARM_LEVEL_ID:
		return false
	if Runtime.game_flow == null:
		return false
	var gf: Node = Runtime.game_flow
	var state_v: Variant = null
	if gf.has_method("get_base_state"):
		state_v = gf.call("get_base_state")
	else:
		state_v = gf.get("base_state")
	if state_v is StringName:
		var st: StringName = state_v
		if st == GameStateNames.MENU or st == GameStateNames.BOOT or st == GameStateNames.LOADING:
			return false
	return true


func _rand_range(range_v: Vector2) -> float:
	return randf_range(minf(range_v.x, range_v.y), maxf(range_v.x, range_v.y))
