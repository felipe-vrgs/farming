@tool
class_name NpcSchedule
extends Resource

## Per-NPC daily schedule (v1: repeats every day).

## Author steps in coarse increments (e.g. 30/60 minutes).
@export var steps: Array[NpcScheduleStep] = []


func is_valid() -> bool:
	for s in steps:
		if s == null:
			return false
		if not s.is_valid():
			return false
	return true
