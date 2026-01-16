class_name WeatherScheduler
extends Node

## WeatherScheduler (v1)
## - Generates a simple day-based rain schedule (segments).
## - Drives WeatherManager via `set_scheduled_rain()` each minute.
## - Persists its state into GameSave (seed + day + segments + dry streak).

@export var enabled: bool = true

@export_group("Daily Chance")
@export_range(0.0, 1.0, 0.01) var base_daily_rain_chance: float = 0.25
@export_range(0.0, 1.0, 0.01) var dry_streak_bonus_per_day: float = 0.08
@export_range(0.0, 1.0, 0.01) var max_daily_rain_chance: float = 0.75

@export_group("Segments")
@export var segment_count_range: Vector2i = Vector2i(1, 2)
## Segment start minute range (inclusive). Default: 06:00..22:00.
@export var segment_start_minute_range: Vector2i = Vector2i(6 * 60, 23 * 60)
## Segment duration range in minutes.
@export var segment_duration_minutes_range: Vector2i = Vector2i(60, 240)
@export var intensity_range: Vector2 = Vector2(0.6, 1.0)

@export_group("Hacks")
@export var first_day_forced_rain_enabled: bool = true
## Always rain at this minute-of-day on day 1 (default: 10:00).
@export var first_day_forced_rain_minute: int = 10 * 60
@export var first_day_forced_rain_duration_minutes: int = 2 * 60

@export_group("Intensity Variation")
## Step the intensity every N minutes while raining.
@export var intensity_variation_step_minutes: int = 30
@export_range(0.0, 1.0, 0.01) var intensity_variation_max_delta: float = 0.22

var _seed: int = 0
var _schedule_day: int = 0
var _segments: Array = []  # Array[Dictionary] {start:int, end:int, intensity:float}
var _dry_streak_days: int = 0

var _last_applied_day: int = -1
var _last_applied_minute: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_time_signals()
	call_deferred("_sync_to_current_time")


func write_save_state(gs: GameSave) -> void:
	if gs == null:
		return
	_ensure_seed()
	gs.weather_schedule_enabled = enabled
	gs.weather_schedule_seed = _seed
	gs.weather_schedule_day = _schedule_day
	gs.weather_schedule_segments = _segments.duplicate(true)
	gs.weather_schedule_dry_streak = _dry_streak_days


func apply_save_state(gs: GameSave) -> void:
	if gs == null:
		return

	enabled = bool(gs.weather_schedule_enabled)
	_seed = int(gs.weather_schedule_seed)
	_schedule_day = int(gs.weather_schedule_day)
	_segments = []
	if gs.weather_schedule_segments is Array:
		_segments = (gs.weather_schedule_segments as Array).duplicate(true)
	_dry_streak_days = int(gs.weather_schedule_dry_streak)

	# Ensure we have a schedule for the current day.
	call_deferred("_sync_to_current_time")


func set_enabled(v: bool) -> void:
	enabled = v
	if not enabled:
		# Do not force-clear rain; just stop driving the manager.
		return
	_sync_to_current_time()


func debug_regenerate_today() -> void:
	var day := int(TimeManager.current_day) if TimeManager != null else _schedule_day
	_schedule_day = 0  # force regen
	_generate_schedule_for_day(day)
	_sync_to_current_time()


func debug_get_today_segments() -> Array:
	var day := int(TimeManager.current_day) if TimeManager != null else _schedule_day
	_generate_schedule_for_day(day)
	return _segments.duplicate(true)


func debug_get_dry_streak_days() -> int:
	return _dry_streak_days


func _connect_time_signals() -> void:
	if TimeManager != null and not TimeManager.time_changed.is_connected(_on_time_changed):
		TimeManager.time_changed.connect(_on_time_changed)
	if EventBus != null and not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func _ensure_seed() -> void:
	if _seed != 0:
		return
	var t := int(Time.get_unix_time_from_system()) if Time != null else 0
	_seed = int(t ^ randi())


func _sync_to_current_time() -> void:
	if TimeManager == null:
		return
	_on_time_changed(
		TimeManager.current_day,
		TimeManager.get_minute_of_day(),
		float(TimeManager.get_day_progress())
	)


func _on_day_started(day_index: int) -> void:
	# Generate a schedule at day start (06:00 tick), but also handle time-changed day transitions.
	_generate_schedule_for_day(int(day_index))


func _on_time_changed(day_index: int, minute_of_day: int, _day_progress: float) -> void:
	if not enabled:
		return
	if day_index != _last_applied_day:
		_generate_schedule_for_day(day_index)
		_last_applied_day = day_index
		_last_applied_minute = -1
	if minute_of_day == _last_applied_minute:
		return
	_last_applied_minute = minute_of_day

	var info := _get_weather_at(minute_of_day)
	var wm := get_parent()
	if wm != null and wm.has_method("set_scheduled_rain"):
		wm.call("set_scheduled_rain", bool(info["raining"]), float(info["intensity"]))


func _generate_schedule_for_day(day_index: int) -> void:
	_ensure_seed()
	var day := int(day_index)
	if day <= 0:
		day = 1

	# If we're moving to a new day, update dry-streak based on whether the previous day had rain.
	if _schedule_day != 0 and day != _schedule_day:
		if _segments.is_empty():
			_dry_streak_days += 1
		else:
			_dry_streak_days = 0

	# If we already generated/persisted the schedule for this day (even if empty), keep it stable.
	if _schedule_day == day:
		return

	_schedule_day = day
	_segments = _roll_segments_for_day(day, _dry_streak_days)


func _get_weather_at(minute_of_day: int) -> Dictionary:
	var m := int(minute_of_day)
	for seg in _segments:
		if seg == null or not (seg is Dictionary):
			continue
		var d: Dictionary = seg
		var start := int(d.get("start", -1))
		var end := int(d.get("end", -1))
		if start < 0 or end < 0:
			continue
		if m >= start and m < end:
			var base := clampf(float(d.get("intensity", 1.0)), 0.0, 1.0)
			return {"raining": true, "intensity": _vary_intensity(base, m, start, end)}
	return {"raining": false, "intensity": 0.0}


func _vary_intensity(base: float, minute_of_day: int, seg_start: int, seg_end: int) -> float:
	var step := maxi(1, int(intensity_variation_step_minutes))
	var bucket := int(floor(float(minute_of_day) / float(step)))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(
		_seed + (_schedule_day * 10007) + (bucket * 97) + (seg_start * 13) + (seg_end * 7)
	)

	# Depend on the starting point: if base intensity is near 0 or 1, keep variation smaller.
	var center_factor := clampf(minf(base, 1.0 - base) * 2.0, 0.0, 1.0)  # 0 at edges, 1 at 0.5
	var amp := (
		clampf(float(intensity_variation_max_delta), 0.0, 1.0) * (0.25 + 0.75 * center_factor)
	)
	var delta := rng.randf_range(-amp, amp)
	return clampf(base + delta, 0.0, 1.0)


func _roll_segments_for_day(day_index: int, dry_streak_days: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_seed + (day_index * 10007) + (dry_streak_days * 99991))

	var force_first_day := first_day_forced_rain_enabled and int(day_index) == 1
	var chance := clampf(
		base_daily_rain_chance + (dry_streak_bonus_per_day * float(maxi(0, dry_streak_days))),
		0.0,
		max_daily_rain_chance
	)
	if not force_first_day and rng.randf() > chance:
		return []

	var count := maxi(
		1,
		rng.randi_range(
			mini(segment_count_range.x, segment_count_range.y),
			maxi(segment_count_range.x, segment_count_range.y)
		)
	)
	var start_min := clampi(
		mini(segment_start_minute_range.x, segment_start_minute_range.y),
		0,
		TimeManager.MINUTES_PER_DAY - 1
	)
	var start_max := clampi(
		maxi(segment_start_minute_range.x, segment_start_minute_range.y),
		0,
		TimeManager.MINUTES_PER_DAY - 1
	)
	var dur_min := maxi(1, mini(segment_duration_minutes_range.x, segment_duration_minutes_range.y))
	var dur_max := maxi(1, maxi(segment_duration_minutes_range.x, segment_duration_minutes_range.y))

	var out: Array = []
	for i in range(count):
		var start := rng.randi_range(start_min, start_max)
		var duration := rng.randi_range(dur_min, dur_max)
		var end := clampi(start + duration, 0, TimeManager.MINUTES_PER_DAY)
		if end <= start:
			continue
		var intensity := rng.randf_range(
			minf(intensity_range.x, intensity_range.y), maxf(intensity_range.x, intensity_range.y)
		)
		out.append({"start": start, "end": end, "intensity": clampf(intensity, 0.0, 1.0)})

	# Hack: always rain at 10:00 on day 1 (or configured minute).
	if force_first_day:
		var forced_m := clampi(
			int(first_day_forced_rain_minute), 0, TimeManager.MINUTES_PER_DAY - 1
		)
		var forced_dur := maxi(1, int(first_day_forced_rain_duration_minutes))
		var forced_end := clampi(forced_m + forced_dur, 0, TimeManager.MINUTES_PER_DAY)
		if forced_end > forced_m:
			var forced_intensity := rng.randf_range(
				minf(intensity_range.x, intensity_range.y),
				maxf(intensity_range.x, intensity_range.y)
			)
			(
				out
				. append(
					{
						"start": forced_m,
						"end": forced_end,
						"intensity": clampf(forced_intensity, 0.0, 1.0),
					}
				)
			)

	# Sort and merge overlaps (keep the stronger intensity).
	out.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			return int((a as Dictionary).get("start", 0)) < int((b as Dictionary).get("start", 0))
	)
	var merged: Array = []
	for seg in out:
		if merged.is_empty():
			merged.append(seg)
			continue
		var last: Dictionary = merged[merged.size() - 1]
		var cur: Dictionary = seg
		var last_end := int(last.get("end", 0))
		var cur_start := int(cur.get("start", 0))
		if cur_start <= last_end:
			last["end"] = maxi(last_end, int(cur.get("end", last_end)))
			last["intensity"] = maxf(
				float(last.get("intensity", 1.0)), float(cur.get("intensity", 1.0))
			)
		else:
			merged.append(cur)

	return merged
