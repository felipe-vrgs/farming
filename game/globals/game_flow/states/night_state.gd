extends GameState

@export var night_minute_of_day: int = 3 * 60
@export var night_ambience_fade_seconds: float = 1.0
@export var night_ambience_volume_db: float = -18.0
@export var night_fade_in_seconds: float = 0.6
@export var night_hold_black_seconds: float = 2.0
@export var night_fade_out_seconds: float = 0.6
@export var night_entry_delay_seconds: float = 3.0
@export var night_darkness_multiplier: float = 3.0
@export var night_end_fade_in_seconds: float = 0.6
@export var night_end_hold_black_seconds: float = 0.35
@export var night_end_fade_out_seconds: float = 1.0

const _PAUSE_REASON_NIGHT := &"night"
const _NIGHT_AMBIENCE := preload("res://assets/music/night_ambience.ogg")

var _exit_started: bool = false
var _run_entry_fade: bool = false
var _defer_night_apply: bool = false
var _start_in_blackout: bool = false
var _skip_entry_transition: bool = false
var _defer_apply_after_load: bool = false
var _post_load_apply_running: bool = false


func enter(prev: StringName = &"") -> void:
	if flow == null:
		return
	_exit_started = false
	_skip_entry_transition = prev == GameStateNames.LOADING
	_run_entry_fade = (prev == GameStateNames.IN_GAME) and not _skip_entry_transition
	_defer_apply_after_load = _skip_entry_transition
	_start_in_blackout = (Runtime != null and bool(Runtime.consume_night_start_in_blackout()))
	_defer_night_apply = _run_entry_fade
	if _defer_night_apply and not _start_in_blackout:
		_apply_pre_night_hold()
	else:
		_apply_night_state()
		if _defer_apply_after_load:
			call_deferred("_ensure_night_state_after_load")
	_connect_exit_trigger()
	_connect_level_change()
	call_deferred("_run_entry_sequence")


func exit(next: StringName = &"") -> void:
	_disconnect_exit_trigger()
	_disconnect_level_change()
	if next == GameStateNames.LOADING:
		# Preserve night state during travel to avoid flicker/extra fades.
		return
	if next == GameStateNames.PAUSED:
		return
	_restore_from_night()


func refresh() -> void:
	# Safe re-assert of night effects without re-running entry sequences.
	if flow == null:
		return
	_apply_night_state()


func on_reveal(_overlay: StringName) -> void:
	refresh()


func handle_unhandled_input(_event: InputEvent) -> StringName:
	if flow == null:
		return GameStateNames.NONE
	if _event == null:
		return GameStateNames.NONE
	if _event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED
	# Block menu inputs during night mode.
	return GameStateNames.NONE


func perform_level_change(
	target_level_id: Enums.Levels, fallback_spawn_point: SpawnPointData = null
) -> bool:
	if flow == null:
		return false
	var ok: bool = await flow.run_loading_action_to_state(
		func() -> bool:
			# Night travel should not persist session state.
			var options := {"spawn_point": fallback_spawn_point}
			if Runtime != null and Runtime.save_manager != null:
				options["level_save"] = Runtime.save_manager.load_session_level_save(
					target_level_id
				)

			if Runtime == null or Runtime.scene_loader == null:
				return false

			var did_load: bool = await Runtime.scene_loader.load_level_and_hydrate(
				target_level_id, options
			)
			if not did_load:
				return false

			return true,
		GameStateNames.NIGHT,
		true
	)
	return ok


func _apply_night_state(enable_controls: bool = true, enable_audio: bool = true) -> void:
	if flow == null:
		return
	flow.force_unpaused()

	if TimeManager != null:
		TimeManager.resume(&"sleep")
		TimeManager.resume(&"auto_sleep")
		TimeManager.set_minute_of_day(night_minute_of_day)
		TimeManager.pause(_PAUSE_REASON_NIGHT)

	if UIManager != null:
		UIManager.hide_all_menus()
		UIManager.hide(UIManager.ScreenName.HUD)
		UIManager.hide(UIManager.ScreenName.VIGNETTE)

	GameplayUtils.set_player_action_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), enable_controls)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), false)
	GameplayUtils.set_hotbar_visible(false)
	GameplayUtils.fade_vignette_out(0.0)

	var player := flow.get_player() as Player
	if player != null and is_instance_valid(player):
		player.set_input_enabled(enable_controls)
		player.set_action_input_enabled(false)
		player.set_night_light_enabled(true)

	if DayNightManager != null:
		DayNightManager.set_night_mode_multiplier(night_darkness_multiplier)

	if enable_audio and SFXManager != null and is_instance_valid(SFXManager):
		if _NIGHT_AMBIENCE != null:
			SFXManager.stop_ambience()
			SFXManager.play_music(
				_NIGHT_AMBIENCE, night_ambience_fade_seconds, night_ambience_volume_db
			)


func _restore_from_night() -> void:
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_NIGHT)

	if DayNightManager != null:
		DayNightManager.clear_night_mode_multiplier()

	var player := flow.get_player() as Player
	if player != null and is_instance_valid(player):
		player.set_night_light_enabled(false)

	GameplayUtils.set_player_action_input_enabled(flow.get_tree(), true)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), true)

	if UIManager != null:
		UIManager.hide_all_menus()

	if SFXManager != null and is_instance_valid(SFXManager):
		# Ensure night ambience is cleared before restoring level audio.
		SFXManager.stop_all()
		SFXManager.restore_level_audio()
		SFXManager.fade_in_music(maxf(0.0, night_end_fade_out_seconds))


func _connect_exit_trigger() -> void:
	if EventBus == null:
		return
	var cb := Callable(self, "_on_night_exit_requested")
	if not EventBus.night_exit_requested.is_connected(cb):
		EventBus.night_exit_requested.connect(cb)


func _connect_level_change() -> void:
	if EventBus == null:
		return
	var cb := Callable(self, "_on_active_level_changed")
	if not EventBus.active_level_changed.is_connected(cb):
		EventBus.active_level_changed.connect(cb)


func _disconnect_exit_trigger() -> void:
	if EventBus == null:
		return
	var cb := Callable(self, "_on_night_exit_requested")
	if EventBus.night_exit_requested.is_connected(cb):
		EventBus.night_exit_requested.disconnect(cb)


func _disconnect_level_change() -> void:
	if EventBus == null:
		return
	var cb := Callable(self, "_on_active_level_changed")
	if EventBus.active_level_changed.is_connected(cb):
		EventBus.active_level_changed.disconnect(cb)


func _on_night_exit_requested(actor: Node) -> void:
	if _exit_started:
		return
	if actor == null or not is_instance_valid(actor):
		return
	if not actor.is_in_group(Groups.PLAYER):
		return
	_exit_started = true
	call_deferred("_run_exit_sequence")


func _on_active_level_changed(_prev: Enums.Levels, _next: Enums.Levels) -> void:
	# Re-assert night state after level travel (player may not be ready yet).
	call_deferred("_ensure_night_state_after_load")


func _run_entry_sequence() -> void:
	if _skip_entry_transition:
		# Returning from loading: keep night state without any re-fade.
		return
	if _run_entry_fade:
		await _perform_night_entry_transition()


func _run_exit_sequence() -> void:
	await _perform_night_end_sleep()

	if flow != null:
		flow.call_deferred("_set_base_state", GameStateNames.IN_GAME, true)

	await _await_wake_ready()
	if UIManager != null:
		await UIManager.blackout_end(maxf(0.0, night_end_fade_out_seconds))


func _perform_night_entry_transition() -> void:
	if _start_in_blackout:
		if _defer_night_apply:
			_apply_night_state(false, false)
			_defer_night_apply = false
		else:
			await get_tree().process_frame
		await _finish_night_entry()
		if UIManager != null:
			await UIManager.blackout_end(maxf(0.0, night_fade_out_seconds))
		return

	if UIManager == null:
		await get_tree().process_frame
		if _defer_night_apply:
			_apply_night_state(false, false)
			_defer_night_apply = false
		await _finish_night_entry()
		return

	await UIManager.blackout_begin(maxf(0.0, night_fade_in_seconds))
	if night_hold_black_seconds > 0.0:
		await get_tree().create_timer(night_hold_black_seconds).timeout
	if _defer_night_apply:
		_apply_night_state(false, false)
		_defer_night_apply = false
	await UIManager.blackout_end(maxf(0.0, night_fade_out_seconds))
	await _finish_night_entry()


func _ensure_night_state_after_load() -> void:
	if _post_load_apply_running:
		return
	_post_load_apply_running = true
	for _i in range(120):
		var player := flow.get_player() as Player if flow != null else null
		if player != null and is_instance_valid(player):
			_apply_night_state()
			player.set_input_enabled(true)
			player.set_action_input_enabled(false)
			player.set_night_light_enabled(true)
			break
		await get_tree().process_frame
	_post_load_apply_running = false


func _perform_night_end_sleep() -> void:
	var on_black := Callable()
	if Runtime != null:
		on_black = Callable(Runtime, "warp_player_to_bed_spawn_for_sleep")
		await (
			Runtime
			. finish_night_flow(
				{
					"pause_reason": _PAUSE_REASON_NIGHT,
					"fade_in_seconds": night_end_fade_in_seconds,
					"hold_black_seconds": night_end_hold_black_seconds,
					"hold_after_tick_seconds": 0.15,
					"fade_out_seconds": night_end_fade_out_seconds,
					"lock_npcs": true,
					"hide_hotbar": true,
					"use_vignette": false,
					"fade_music": false,
					"on_black": on_black,
				}
			)
		)
		return

	await (
		SleepService
		. sleep_to_6am(
			get_tree(),
			{
				"pause_reason": _PAUSE_REASON_NIGHT,
				"fade_in_seconds": night_end_fade_in_seconds,
				"hold_black_seconds": night_end_hold_black_seconds,
				"hold_after_tick_seconds": 0.15,
				"fade_out_seconds": night_end_fade_out_seconds,
				"lock_npcs": true,
				"hide_hotbar": true,
				"use_vignette": false,
				"fade_music": false,
				"on_black": on_black,
				"defer_blackout_end": true,
				"defer_restore": true,
				"force_advance_day": true,
			}
		)
	)


func _apply_pre_night_hold() -> void:
	if flow == null:
		return
	# Keep HUD visible briefly, but block tool usage before the night fade.
	if TimeManager != null:
		TimeManager.pause(_PAUSE_REASON_NIGHT)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_player_action_input_enabled(flow.get_tree(), false)


func _finish_night_entry() -> void:
	if flow == null:
		return
	if night_entry_delay_seconds > 0.0:
		await get_tree().create_timer(night_entry_delay_seconds).timeout

	GameplayUtils.set_player_input_enabled(flow.get_tree(), true)
	GameplayUtils.set_player_action_input_enabled(flow.get_tree(), false)

	var player := flow.get_player() as Player
	if player != null and is_instance_valid(player):
		player.set_input_enabled(true)
		player.set_action_input_enabled(false)
		player.set_night_light_enabled(true)

	if SFXManager != null and is_instance_valid(SFXManager):
		if _NIGHT_AMBIENCE != null:
			SFXManager.stop_ambience()
			SFXManager.play_music(
				_NIGHT_AMBIENCE, night_ambience_fade_seconds, night_ambience_volume_db
			)


func _await_wake_ready() -> void:
	if flow == null:
		return
	for _i in range(180):
		var ready := true

		if TimeManager != null:
			var minute := int(TimeManager.get_minute_of_day())
			if minute != int(TimeManager.DAY_TICK_MINUTE):
				ready = false

		var st: StringName = flow.get_base_state()
		if st != GameStateNames.IN_GAME:
			ready = false

		var player := flow.get_player() as Player
		if player == null or not is_instance_valid(player):
			ready = false
		else:
			if not player.input_enabled or not player.action_input_enabled:
				ready = false

		if ready:
			return
		await get_tree().process_frame
