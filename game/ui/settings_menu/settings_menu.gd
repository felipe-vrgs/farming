class_name SettingsMenu
extends Control

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Panel

@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckBox = %VsyncCheck

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var ambience_slider: HSlider = %AmbienceSlider

@onready var back_button: Button = %BackButton

var _is_syncing_ui := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	if backdrop:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_build_window_mode_options()
	_build_resolution_options()
	_setup_audio_sliders()

	if window_mode_option:
		window_mode_option.item_selected.connect(_on_window_mode_selected)
	if resolution_option:
		resolution_option.item_selected.connect(_on_resolution_selected)
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)

	if master_slider:
		master_slider.value_changed.connect(
			func(v: float) -> void: _on_volume_changed(&"Master", v)
		)
	if music_slider:
		music_slider.value_changed.connect(func(v: float) -> void: _on_volume_changed(&"Music", v))
	if sfx_slider:
		sfx_slider.value_changed.connect(func(v: float) -> void: _on_volume_changed(&"SFX", v))
	if ambience_slider:
		ambience_slider.value_changed.connect(
			func(v: float) -> void: _on_volume_changed(&"Ambience", v)
		)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	visibility_changed.connect(_sync_from_settings)
	if SettingsManager != null:
		SettingsManager.settings_changed.connect(_sync_from_settings)

	_sync_from_settings()


func _build_window_mode_options() -> void:
	if window_mode_option == null:
		return
	window_mode_option.clear()
	window_mode_option.add_item("Windowed", 0)
	window_mode_option.add_item("Fullscreen", 1)
	window_mode_option.add_item("Borderless", 2)


func _build_resolution_options() -> void:
	if resolution_option == null:
		return
	resolution_option.clear()

	var list: Array[Vector2i] = []
	if SettingsManager != null and SettingsManager.has_method("get_available_resolutions"):
		list = SettingsManager.get_available_resolutions()
	else:
		list = [Vector2i(1280, 720)]

	for i in range(list.size()):
		var r := list[i]
		resolution_option.add_item("%dx%d" % [r.x, r.y], i)
		resolution_option.set_item_metadata(i, r)


func _setup_audio_sliders() -> void:
	for s in [master_slider, music_slider, sfx_slider, ambience_slider]:
		if s == null:
			continue
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01


func _sync_from_settings() -> void:
	if not is_visible_in_tree():
		return
	if SettingsManager == null:
		return

	_is_syncing_ui = true

	# Window mode
	var mode := SettingsManager.window_mode
	if window_mode_option != null:
		var idx := 0
		if mode == SettingsManager.WINDOW_MODE_FULLSCREEN:
			idx = 1
		elif mode == SettingsManager.WINDOW_MODE_BORDERLESS:
			idx = 2
		window_mode_option.select(idx)

	# Resolution
	if resolution_option != null:
		var target: Vector2i = SettingsManager.resolution
		var best := -1
		for i in range(resolution_option.item_count):
			var meta = resolution_option.get_item_metadata(i)
			if meta is Vector2i and meta == target:
				best = i
				break
		if best >= 0:
			resolution_option.select(best)
		resolution_option.disabled = (mode != SettingsManager.WINDOW_MODE_WINDOWED)

	# Vsync
	if vsync_check != null:
		vsync_check.button_pressed = SettingsManager.vsync_enabled

	# Volumes
	if master_slider != null:
		master_slider.value = SettingsManager.get_volume_linear(&"Master")
	if music_slider != null:
		music_slider.value = SettingsManager.get_volume_linear(&"Music")
	if sfx_slider != null:
		sfx_slider.value = SettingsManager.get_volume_linear(&"SFX")
	if ambience_slider != null:
		ambience_slider.value = SettingsManager.get_volume_linear(&"Ambience")

	_is_syncing_ui = false


func _on_window_mode_selected(index: int) -> void:
	if _is_syncing_ui or SettingsManager == null:
		return
	match index:
		0:
			SettingsManager.set_window_mode(SettingsManager.WINDOW_MODE_WINDOWED)
		1:
			SettingsManager.set_window_mode(SettingsManager.WINDOW_MODE_FULLSCREEN)
		2:
			SettingsManager.set_window_mode(SettingsManager.WINDOW_MODE_BORDERLESS)


func _on_resolution_selected(index: int) -> void:
	if _is_syncing_ui or SettingsManager == null or resolution_option == null:
		return
	var meta = resolution_option.get_item_metadata(index)
	if meta is Vector2i:
		SettingsManager.set_resolution(meta)


func _on_vsync_toggled(pressed: bool) -> void:
	if _is_syncing_ui or SettingsManager == null:
		return
	SettingsManager.set_vsync_enabled(pressed)


func _on_volume_changed(bus: StringName, value: float) -> void:
	if _is_syncing_ui or SettingsManager == null:
		return
	SettingsManager.set_volume_linear(bus, value)


func _on_back_pressed() -> void:
	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.SETTINGS_MENU)
