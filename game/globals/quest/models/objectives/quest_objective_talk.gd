class_name QuestObjectiveTalk
extends QuestObjective

@export var npc_id: StringName = &""


func describe() -> String:
	if String(npc_id).is_empty():
		return "Talk"
	return "Talk to %s" % String(npc_id)


func apply_event(event_id: StringName, payload: Dictionary, progress: int) -> int:
	var p := maxi(0, int(progress))
	if event_id != &"talked_to_npc":
		return p
	if payload == null:
		return p
	var got: StringName = payload.get("npc_id", &"")
	if String(npc_id).is_empty():
		# If the objective didn't specify an npc, treat any talk as completion.
		return target_count
	if got != npc_id:
		return p
	return target_count
