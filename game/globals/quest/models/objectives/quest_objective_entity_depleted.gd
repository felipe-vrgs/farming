@tool
class_name QuestObjectiveEntityDepleted
extends QuestObjective

## Counts entity depletion events by kind (e.g. "tree", "rock").
@export var kind: StringName = &""


func describe() -> String:
	if String(kind).is_empty():
		return "Deplete %d entities" % int(target_count)
	return "Deplete %d %s" % [int(target_count), String(kind)]


func apply_event(event_id: StringName, payload: Dictionary, progress: int) -> int:
	var p := maxi(0, int(progress))
	if event_id != &"entity_depleted":
		return p
	if payload == null:
		return p
	var got: StringName = payload.get("kind", &"")
	if not String(kind).is_empty() and got != kind:
		return p
	return p + 1
