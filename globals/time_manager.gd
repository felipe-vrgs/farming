extends Node

signal day_started(day_index: int)

## How long a full day lasts in real-time seconds.
@export var day_duration_seconds: float = 10.0

var current_day: int = 1
var _elapsed: float = 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= day_duration_seconds:
		_elapsed = 0.0
		advance_day()

func advance_day() -> void:
	current_day += 1
	day_started.emit(current_day)
	print("TimeManager: Day %d has begun!" % current_day)

func get_day_progress() -> float:
	return _elapsed / day_duration_seconds

