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
	await (
		SleepService
		. sleep_to_6am(
			get_tree(),
			{
				"pause_reason": &"sleep",
				"fade_in_seconds": fade_in_seconds,
				"hold_black_seconds": hold_black_seconds,
				"hold_after_tick_seconds": hold_after_tick_seconds,
				"fade_out_seconds": fade_out_seconds,
				"lock_npcs": false,
				"hide_hotbar": true,
				"use_vignette": true,
				"fade_music": true,
			}
		)
	)

	_sleeping = false
