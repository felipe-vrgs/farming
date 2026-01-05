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

	# Lock controls and pause normal time progression.
	if Runtime != null and Runtime.flow_manager != null:
		Runtime.flow_manager.request_flow_state(Enums.FlowState.CUTSCENE)

	# Fade in to black (use the existing vignette overlay).
	var v: Node = null
	if UIManager != null:
		v = UIManager.show(UIManager.ScreenName.VIGNETTE)
	if v != null and v.has_method("fade_in"):
		v.call("fade_in", maxf(0.0, fade_in_seconds))

	await _wait_seconds(maxf(0.0, fade_in_seconds) + maxf(0.0, hold_black_seconds))

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

	# Fade back out.
	if v != null and v.has_method("fade_out"):
		v.call("fade_out", maxf(0.0, fade_out_seconds))
	await _wait_seconds(maxf(0.0, fade_out_seconds))

	# Restore gameplay state.
	if Runtime != null and Runtime.flow_manager != null:
		Runtime.flow_manager.request_flow_state(Enums.FlowState.RUNNING)

	_sleeping = false


func _wait_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
