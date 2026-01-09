@tool
class_name QuestObjective
extends Resource

## QuestObjective
## - Pure data + pure logic: given a quest event, update numeric progress.
## - Runtime progress is stored in QuestManager/QuestSave (NOT in this Resource).

@export var target_count: int = 1:
	set(v):
		target_count = maxi(1, int(v))


func describe() -> String:
	# UI-friendly description; concrete objectives should override.
	return "Objective"


func apply_event(_event_id: StringName, _payload: Dictionary, progress: int) -> int:
	# Return updated progress. Concrete objectives should override.
	return maxi(0, int(progress))


func is_completed(progress: int) -> bool:
	return int(progress) >= int(target_count)
