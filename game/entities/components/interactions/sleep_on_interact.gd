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


func _ready() -> void:
	_sleeping = false


func try_interact(ctx: InteractionContext) -> bool:
	if not ctx.is_use():
		return false

	if _sleeping:
		return true

	_start_sleep()
	return true


func _start_sleep() -> void:
	_sleeping = true
	if Runtime != null and Runtime.has_method("request_bed_sleep"):
		await Runtime.request_bed_sleep(
			fade_in_seconds, hold_black_seconds, hold_after_tick_seconds, fade_out_seconds
		)

	_sleeping = false
