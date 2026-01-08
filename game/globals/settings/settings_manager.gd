extends Node

## Persistent settings manager.
## - Loads from user://settings.cfg on startup
## - Applies to DisplayServer/AudioServer immediately
## - Saves when values change

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"

const SECTION_DISPLAY := "display"
const SECTION_AUDIO := "audio"

const KEY_WINDOW_MODE := "window_mode"  # "windowed" | "fullscreen" | "borderless"
const KEY_RESOLUTION_X := "resolution_x"
const KEY_RESOLUTION_Y := "resolution_y"
const KEY_VSYNC := "vsync"

const KEY_VOL_MASTER := "vol_master"  # linear 0..1
const KEY_VOL_MUSIC := "vol_music"
const KEY_VOL_SFX := "vol_sfx"
const KEY_VOL_AMBIENCE := "vol_ambience"

const WINDOW_MODE_WINDOWED := "windowed"
const WINDOW_MODE_FULLSCREEN := "fullscreen"
const WINDOW_MODE_BORDERLESS := "borderless"

var _cfg := ConfigFile.new()

var window_mode: String = WINDOW_MODE_WINDOWED
var resolution: Vector2i = Vector2i(1280, 720)
var vsync_enabled: bool = true

var vol_master: float = 1.0
var vol_music: float = 1.0
var vol_sfx: float = 1.0
var vol_ambience: float = 1.0


func _ready() -> void:
	# Keep settings alive/active even if SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	# When running from the editor, applying window settings immediately can be too early.
	# Delay one frame so the main window is fully initialized.
	call_deferred("_apply_startup")


func _apply_startup() -> void:
	if get_tree() != null:
		await get_tree().process_frame
	apply_settings()


func load_settings() -> void:
	var err := _cfg.load(CONFIG_PATH)
	if err != OK:
		# First run (or corrupted file): keep defaults.
		return

	window_mode = str(_cfg.get_value(SECTION_DISPLAY, KEY_WINDOW_MODE, window_mode))
	resolution = Vector2i(
		int(_cfg.get_value(SECTION_DISPLAY, KEY_RESOLUTION_X, resolution.x)),
		int(_cfg.get_value(SECTION_DISPLAY, KEY_RESOLUTION_Y, resolution.y))
	)
	vsync_enabled = bool(_cfg.get_value(SECTION_DISPLAY, KEY_VSYNC, vsync_enabled))

	vol_master = float(_cfg.get_value(SECTION_AUDIO, KEY_VOL_MASTER, vol_master))
	vol_music = float(_cfg.get_value(SECTION_AUDIO, KEY_VOL_MUSIC, vol_music))
	vol_sfx = float(_cfg.get_value(SECTION_AUDIO, KEY_VOL_SFX, vol_sfx))
	vol_ambience = float(_cfg.get_value(SECTION_AUDIO, KEY_VOL_AMBIENCE, vol_ambience))

	_normalize()


func save_settings() -> void:
	_cfg.set_value(SECTION_DISPLAY, KEY_WINDOW_MODE, window_mode)
	_cfg.set_value(SECTION_DISPLAY, KEY_RESOLUTION_X, resolution.x)
	_cfg.set_value(SECTION_DISPLAY, KEY_RESOLUTION_Y, resolution.y)
	_cfg.set_value(SECTION_DISPLAY, KEY_VSYNC, vsync_enabled)

	_cfg.set_value(SECTION_AUDIO, KEY_VOL_MASTER, vol_master)
	_cfg.set_value(SECTION_AUDIO, KEY_VOL_MUSIC, vol_music)
	_cfg.set_value(SECTION_AUDIO, KEY_VOL_SFX, vol_sfx)
	_cfg.set_value(SECTION_AUDIO, KEY_VOL_AMBIENCE, vol_ambience)

	_cfg.save(CONFIG_PATH)


func apply_settings() -> void:
	_apply_display()
	_apply_audio()
	settings_changed.emit()


func set_window_mode(mode: String) -> void:
	if (
		mode != WINDOW_MODE_WINDOWED
		and mode != WINDOW_MODE_FULLSCREEN
		and mode != WINDOW_MODE_BORDERLESS
	):
		return
	if window_mode == mode:
		return
	window_mode = mode
	_normalize()
	_apply_display()
	save_settings()
	settings_changed.emit()


func set_resolution(size: Vector2i) -> void:
	if size.x <= 0 or size.y <= 0:
		return
	if resolution == size:
		return
	resolution = size
	_normalize()
	_apply_display()
	save_settings()
	settings_changed.emit()


func set_vsync_enabled(enabled: bool) -> void:
	if vsync_enabled == enabled:
		return
	vsync_enabled = enabled
	_apply_display()
	save_settings()
	settings_changed.emit()


func set_volume_linear(bus_name: StringName, linear: float) -> void:
	var v := clampf(linear, 0.0, 1.0)
	match String(bus_name):
		"Master":
			if is_equal_approx(vol_master, v):
				return
			vol_master = v
		"Music":
			if is_equal_approx(vol_music, v):
				return
			vol_music = v
		"SFX":
			if is_equal_approx(vol_sfx, v):
				return
			vol_sfx = v
		"Ambience":
			if is_equal_approx(vol_ambience, v):
				return
			vol_ambience = v
		_:
			return

	_apply_audio()
	save_settings()
	settings_changed.emit()


func get_volume_linear(bus_name: StringName) -> float:
	match String(bus_name):
		"Master":
			return vol_master
		"Music":
			return vol_music
		"SFX":
			return vol_sfx
		"Ambience":
			return vol_ambience
		_:
			return 1.0


func get_available_resolutions() -> Array[Vector2i]:
	# Keep this list short and safe for low-res pixel art.
	var list: Array[Vector2i] = [
		Vector2i(640, 360),
		Vector2i(960, 540),
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
	]

	# Filter out resolutions larger than the current monitor (mostly relevant for windowed).
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var filtered: Array[Vector2i] = []
	for r in list:
		if r.x <= screen.x and r.y <= screen.y:
			filtered.append(r)
	if filtered.is_empty():
		filtered.append(Vector2i(1280, 720))
	return filtered


func _normalize() -> void:
	# Clamp volumes and sanitize mode.
	vol_master = clampf(vol_master, 0.0, 1.0)
	vol_music = clampf(vol_music, 0.0, 1.0)
	vol_sfx = clampf(vol_sfx, 0.0, 1.0)
	vol_ambience = clampf(vol_ambience, 0.0, 1.0)

	if (
		window_mode != WINDOW_MODE_WINDOWED
		and window_mode != WINDOW_MODE_FULLSCREEN
		and window_mode != WINDOW_MODE_BORDERLESS
	):
		window_mode = WINDOW_MODE_WINDOWED

	if resolution.x <= 0 or resolution.y <= 0:
		resolution = Vector2i(1280, 720)


func _apply_display() -> void:
	# Vsync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)

	# Window mode + borderless flag
	if window_mode == WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	# Windowed / Borderless windowed
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var borderless := window_mode == WINDOW_MODE_BORDERLESS
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)

	var size := resolution
	if window_mode == WINDOW_MODE_BORDERLESS:
		size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())

	DisplayServer.window_set_size(size)

	# Center window when possible (Windowed only; borderless usually fills screen).
	if window_mode == WINDOW_MODE_WINDOWED:
		var screen_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
		var pos := Vector2i(
			int((screen_size.x - size.x) / 2.0), int((screen_size.y - size.y) / 2.0)
		)
		DisplayServer.window_set_position(pos)


func _apply_audio() -> void:
	_set_bus_volume("Master", vol_master)
	_set_bus_volume("Music", vol_music)
	_set_bus_volume("SFX", vol_sfx)
	_set_bus_volume("Ambience", vol_ambience)


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
