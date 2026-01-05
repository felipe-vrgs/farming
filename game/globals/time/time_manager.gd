extends Node

## GameClock (v1):
## - Provides a stable notion of in-game time for schedules and simulation.
## - Keeps backward compatibility with the previous TimeManager:
##   - `current_day` int
##   - `advance_day()`, `reset()`, `get_day_progress()`
##   - emits `EventBus.day_started(day_index)`

signal time_changed(day_index: int, minute_of_day: int, day_progress: float)
signal paused_changed(is_paused: bool)

## In-game clock scale.
const HOURS_PER_DAY := 24
const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := HOURS_PER_DAY * MINUTES_PER_HOUR
const SECONDS_PER_DAY := MINUTES_PER_DAY * 60

## The time when the "day start" hooks/ticks fire (06:00 AM).
const DAY_TICK_MINUTE := 6 * 60

## How long a full in-game day lasts in real-time seconds.
@export var day_duration_seconds: float = 60.0 * 5  # 5 minutes

## Day index (1-based for now, matches existing save/debug expectations).
var current_day: int = 1

## Elapsed real-time seconds into the current day [0..day_duration_seconds).
var _elapsed_s: float = 0.0

## Pause reasons (multiple systems can pause independently).
var _pause_reasons: Dictionary[StringName, bool] = {}

## Cached to avoid spamming signals when nothing changed.
var _last_minute_of_day: int = -1

## Track if the 06:00 tick was already emitted for the current day.
var _day_tick_emitted: bool = false


func _process(delta: float) -> void:
	if is_paused():
		return

	_elapsed_s += delta
	if day_duration_seconds <= 0.0:
		return

	if _elapsed_s >= day_duration_seconds:
		# Carry remainder so changing time_scale doesn't lose sub-frame precision.
		_elapsed_s = fmod(_elapsed_s, day_duration_seconds)
		advance_day()

	_emit_time_if_changed()

	# Day tick detection at 06:00 crossing.
	if not _day_tick_emitted:
		var tick_time_s := (float(DAY_TICK_MINUTE) / float(MINUTES_PER_DAY)) * day_duration_seconds
		if _elapsed_s >= tick_time_s:
			_emit_day_tick()


func pause(reason: StringName) -> void:
	if String(reason).is_empty():
		return
	_pause_reasons[reason] = true
	paused_changed.emit(is_paused())


func resume(reason: StringName) -> void:
	if String(reason).is_empty():
		return
	_pause_reasons.erase(reason)
	paused_changed.emit(is_paused())


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


func reset() -> void:
	current_day = 1
	_elapsed_s = 0.0
	_pause_reasons.clear()
	_last_minute_of_day = -1
	_day_tick_emitted = false
	_emit_time_if_changed(true)


func advance_day() -> void:
	current_day += 1
	_day_tick_emitted = false
	print("TimeManager: Day %d has begun!" % current_day)
	_emit_time_if_changed(true)


func _emit_day_tick() -> void:
	_day_tick_emitted = true
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.day_started.emit(current_day)
	elif EventBus != null:
		EventBus.day_started.emit(current_day)

	print("TimeManager: 06:00 tick for Day %d emitted." % current_day)


## Normalized day progress [0..1).
func get_day_progress() -> float:
	if day_duration_seconds <= 0.0:
		return 0.0
	return clampf(_elapsed_s / day_duration_seconds, 0.0, 0.999999)


## In-game seconds since start of day [0..SECONDS_PER_DAY).
func get_time_of_day_seconds() -> float:
	return get_day_progress() * float(SECONDS_PER_DAY)


## In-game minute index since start of day [0..MINUTES_PER_DAY-1].
func get_minute_of_day() -> int:
	return int(floor(get_day_progress() * float(MINUTES_PER_DAY))) % MINUTES_PER_DAY


func get_hour() -> int:
	return int(floor(float(get_minute_of_day()) / float(MINUTES_PER_HOUR)))


func get_minute() -> int:
	return int(get_minute_of_day() % MINUTES_PER_HOUR)


## Set the in-game time-of-day by minute index [0..MINUTES_PER_DAY-1].
func set_minute_of_day(minute_of_day: int) -> void:
	var m := clampi(minute_of_day, 0, MINUTES_PER_DAY - 1)
	_elapsed_s = (float(m) / float(MINUTES_PER_DAY)) * day_duration_seconds
	_emit_time_if_changed(true)


## Utility for schedules: absolute minutes since day 1 start.
func get_absolute_minute() -> int:
	return (max(0, current_day - 1) * MINUTES_PER_DAY) + get_minute_of_day()


## Explicitly advance to 06:00 AM.
## - Advances day index if current time is >= 06:00.
## - Triggers the 06:00 day tick immediately.
func sleep_to_6am() -> int:
	if get_minute_of_day() >= DAY_TICK_MINUTE:
		advance_day()

	set_minute_of_day(DAY_TICK_MINUTE)
	_emit_day_tick()
	return current_day


func _emit_time_if_changed(force: bool = false) -> void:
	var m := get_minute_of_day()
	if not force and m == _last_minute_of_day:
		return
	_last_minute_of_day = m
	time_changed.emit(current_day, m, get_day_progress())
