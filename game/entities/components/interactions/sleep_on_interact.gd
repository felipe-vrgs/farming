class_name SleepOnInteract
extends InteractableComponent

## Interaction behavior for a Bed or sleeping spot.
## Triggers sleep_to_6am and waits for the day tick to complete.

@export_group("Sleep Timing")
@export var fade_in_seconds: float = 0.6
@export var hold_black_seconds: float = 0.35
@export var hold_after_tick_seconds: float = 0.15
@export var fade_out_seconds: float = 0.6

var _sleeping: bool = false


func try_interact(ctx: InteractionContext) -> bool:
	if not ctx.is_use():
		return false

	if _sleeping:
		return true

	_start_sleep()
	return true


func _start_sleep() -> void:
	_sleeping = true

	# Lock controls and pause time, but keep the game in RUNNING flow state so
	# day-tick autosave/capture can run during sleep.
	if TimeManager != null:
		TimeManager.pause(&"sleep")
	GameplayUtils.set_player_input_enabled(get_tree(), false)
	GameplayUtils.set_hotbar_visible(false)

	# Fade music out as we go to black.
	if is_instance_valid(SFXManager) and SFXManager.has_method("fade_out_music"):
		SFXManager.fade_out_music(maxf(0.0, fade_in_seconds))

	# Fade in to black using the loading screen blackout (keep vignette for style).
	var v: Node = null
	var loading: LoadingScreen = null
	if UIManager != null:
		v = UIManager.show(UIManager.ScreenName.VIGNETTE)
		loading = UIManager.acquire_loading_screen()

	if v != null and v.has_method("fade_in"):
		v.call("fade_in", maxf(0.0, fade_in_seconds))

	if loading != null:
		await loading.fade_out(maxf(0.0, fade_in_seconds))
	else:
		# Best-effort timing even if UI isn't present (headless/tests).
		await _wait_seconds(maxf(0.0, fade_in_seconds))

	await _wait_seconds(maxf(0.0, hold_black_seconds))

	var target_day: int = -1
	if TimeManager != null:
		target_day = int(TimeManager.sleep_to_6am())

		# Wait for the day tick pipeline to finish (autosave, offline sim, etc.).
		if EventBus != null:
			# Wait for the matching completion (safety in case multiple ticks happen).
			while true:
				var completed_day: Variant = await EventBus.day_tick_completed
				if target_day < 0 or int(completed_day) == target_day:
					break

	await _wait_seconds(maxf(0.0, hold_after_tick_seconds))

	# Fade music back in as we return from black.
	if is_instance_valid(SFXManager) and SFXManager.has_method("fade_in_music"):
		SFXManager.fade_in_music(maxf(0.0, fade_out_seconds))

	# Fade back out.
	if v != null and v.has_method("fade_out"):
		v.call("fade_out", maxf(0.0, fade_out_seconds))
	if loading != null:
		await loading.fade_in(maxf(0.0, fade_out_seconds))
		if UIManager != null:
			UIManager.release_loading_screen()
	else:
		await _wait_seconds(maxf(0.0, fade_out_seconds))

	# Restore gameplay state.
	if TimeManager != null:
		TimeManager.resume(&"sleep")
	GameplayUtils.set_player_input_enabled(get_tree(), true)
	GameplayUtils.set_hotbar_visible(true)

	_sleeping = false


func _wait_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
