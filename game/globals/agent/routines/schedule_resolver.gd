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
			break

	return out


## Returns the next step index in chronological order (by start_minute_of_day),
## wrapping to the earliest step. Returns -1 if no valid next step exists.
static func get_next_step_index(schedule: NpcSchedule, current_step_index: int) -> int:
	if schedule == null or schedule.steps.is_empty():
		return -1
	if current_step_index < 0 or current_step_index >= schedule.steps.size():
		return -1

	var current := schedule.steps[current_step_index]
	if current == null:
		return -1

	var cur_start := clampi(current.start_minute_of_day, 0, _MINUTES_PER_DAY - 1)

	var best_after_idx := -1
	var best_after_start := INF
	var best_wrap_idx := -1
	var best_wrap_start := INF

	for i in range(schedule.steps.size()):
		if i == current_step_index:
			continue
		var s := schedule.steps[i]
		if s == null or not s.is_valid():
			continue
		var start := clampi(s.start_minute_of_day, 0, _MINUTES_PER_DAY - 1)
		if start > cur_start and start < best_after_start:
			best_after_start = start
			best_after_idx = i
		if start < best_wrap_start:
			best_wrap_start = start
			best_wrap_idx = i

	return best_after_idx if best_after_idx != -1 else best_wrap_idx


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
