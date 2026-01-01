class_name ScheduleResolver
extends RefCounted

## ScheduleResolver - pure utility for resolving NPC schedules.
##
## Given an NpcSchedule and a minute_of_day, returns which step is active
## and the progress within that step.

const _MINUTES_PER_DAY := 24 * 60


class Resolved:
	var step: NpcScheduleStep = null
	var step_index: int = -1
	var minute_of_day: int = 0
	var progress: float = 0.0

	func is_travel_step() -> bool:
		return step != null and step.kind == NpcScheduleStep.Kind.TRAVEL

## Resolve a schedule at a given minute. Returns the active step and progress.
static func resolve(schedule: NpcSchedule, minute_of_day: int) -> Resolved:
	var out := Resolved.new()
	out.minute_of_day = _normalize_minute(minute_of_day)
	if schedule == null or schedule.steps.is_empty():
		return out

	for i in range(schedule.steps.size()):
		var step: NpcScheduleStep = schedule.steps[i]
		if step == null or not step.is_valid():
			continue
		var start: int = clampi(step.start_minute_of_day, 0, _MINUTES_PER_DAY - 1)
		var end_val: int = start + max(1, step.duration_minutes)
		if _is_minute_in_range(out.minute_of_day, start, end_val):
			out.step = step
			out.step_index = i
			out.progress = _compute_progress(out.minute_of_day, start, end_val)

	return out

## Calculate remaining minutes in a step.
static func get_step_remaining_minutes(minute_of_day: int, step: NpcScheduleStep) -> int:
	var m := _normalize_minute(minute_of_day)
	var start: int = clampi(step.start_minute_of_day, 0, _MINUTES_PER_DAY - 1)
	var end_val: int = start + max(1, step.duration_minutes)
	if end_val <= _MINUTES_PER_DAY:
		return maxi(1, end_val - m)
	var wrapped_end := end_val % _MINUTES_PER_DAY
	if m >= start:
		return maxi(1, end_val - m)
	return maxi(1, wrapped_end - m)

static func _normalize_minute(m: int) -> int:
	var mm := m % _MINUTES_PER_DAY
	if mm < 0:
		mm += _MINUTES_PER_DAY
	return mm

static func _is_minute_in_range(m: int, start: int, end_val: int) -> bool:
	if end_val <= _MINUTES_PER_DAY:
		return m >= start and m < end_val
	var wrapped_end := end_val % _MINUTES_PER_DAY
	return m >= start or m < wrapped_end

static func _compute_progress(m: int, start: int, end_val: int) -> float:
	var dur: int = max(1, end_val - start)
	var elapsed: int = 0
	if end_val <= _MINUTES_PER_DAY:
		elapsed = clampi(m - start, 0, dur)
	else:
		if m >= start:
			elapsed = m - start
		else:
			elapsed = (_MINUTES_PER_DAY - start) + m
		elapsed = clampi(elapsed, 0, dur)
	return clampf(float(elapsed) / float(dur), 0.0, 1.0)
