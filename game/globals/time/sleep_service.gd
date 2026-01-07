class_name SleepService
extends Object

## Shared sleep pipeline used by both bed interaction and forced sleep:
## - Pause TimeManager (reason)
## - Lock player inputs + (optionally) NPC controllers + hotbar
## - Fade to black
## - Optional hook while black (e.g. show modal, warp player)
## - Sleep to 06:00 and wait for day tick pipeline completion
## - Fade back in and restore controls


static func sleep_to_6am(scene_tree: SceneTree, options: Dictionary = {}) -> void:
	if scene_tree == null:
		return

	var pause_reason: StringName = options.get("pause_reason", &"sleep")
	var fade_in_seconds: float = float(options.get("fade_in_seconds", 0.6))
	var hold_black_seconds: float = float(options.get("hold_black_seconds", 0.35))
	var hold_after_tick_seconds: float = float(options.get("hold_after_tick_seconds", 0.15))
	var fade_out_seconds: float = float(options.get("fade_out_seconds", 0.6))

	var lock_npcs: bool = bool(options.get("lock_npcs", true))
	var hide_hotbar: bool = bool(options.get("hide_hotbar", true))
	var use_vignette: bool = bool(options.get("use_vignette", true))
	var fade_music: bool = bool(options.get("fade_music", true))

	var on_black: Callable = options.get("on_black", Callable())

	# Lock controls and pause time, but keep the game in RUNNING flow state so
	# day-tick autosave/capture can run during sleep.
	if TimeManager != null:
		TimeManager.pause(pause_reason)
	GameplayUtils.set_player_input_enabled(scene_tree, false)
	if lock_npcs:
		GameplayUtils.set_npc_controllers_enabled(scene_tree, false)
	if hide_hotbar:
		GameplayUtils.set_hotbar_visible(false)

	# Fade music out as we go to black.
	if fade_music and is_instance_valid(SFXManager) and SFXManager.has_method("fade_out_music"):
		SFXManager.fade_out_music(maxf(0.0, fade_in_seconds))

	# Style: vignette + blackout.
	if use_vignette:
		GameplayUtils.fade_vignette_in(maxf(0.0, fade_in_seconds))

	if UIManager != null and UIManager.has_method("blackout_begin"):
		await UIManager.blackout_begin(maxf(0.0, fade_in_seconds))
	else:
		await _wait_seconds(scene_tree, maxf(0.0, fade_in_seconds))

	await _wait_seconds(scene_tree, maxf(0.0, hold_black_seconds))

	# Optional hook while black (modal/warp/etc).
	if on_black != null and on_black.is_valid():
		await _await_callable(on_black)

	var target_day: int = -1
	if TimeManager != null:
		target_day = int(TimeManager.sleep_to_6am())

		# Wait for the day tick pipeline to finish (autosave, offline sim, etc.).
		if EventBus != null:
			while true:
				var completed_day: Variant = await EventBus.day_tick_completed
				if target_day < 0 or int(completed_day) == target_day:
					break

	await _wait_seconds(scene_tree, maxf(0.0, hold_after_tick_seconds))

	# Fade music back in as we return from black.
	if fade_music and is_instance_valid(SFXManager) and SFXManager.has_method("fade_in_music"):
		SFXManager.fade_in_music(maxf(0.0, fade_out_seconds))

	# Fade back out.
	if use_vignette:
		GameplayUtils.fade_vignette_out(maxf(0.0, fade_out_seconds))

	if UIManager != null and UIManager.has_method("blackout_end"):
		await UIManager.blackout_end(maxf(0.0, fade_out_seconds))
	else:
		await _wait_seconds(scene_tree, maxf(0.0, fade_out_seconds))

	# Restore gameplay state.
	if TimeManager != null:
		TimeManager.resume(pause_reason)
	GameplayUtils.set_player_input_enabled(scene_tree, true)
	if lock_npcs:
		GameplayUtils.set_npc_controllers_enabled(scene_tree, true)
	if hide_hotbar:
		GameplayUtils.set_hotbar_visible(true)


static func _wait_seconds(scene_tree: SceneTree, seconds: float) -> void:
	if seconds <= 0.0:
		return
	await scene_tree.create_timer(seconds).timeout


static func _await_callable(cb: Callable) -> void:
	if cb == null or not cb.is_valid():
		return
	# If the callable yields, Godot returns an awaitable function state here.
	await cb.call()
