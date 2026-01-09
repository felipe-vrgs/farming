@tool
class_name QuestObjectiveTalk
extends QuestObjectiveTimelineCompleted

@export var npc_id: StringName = &""


func describe() -> String:
	var s := display_text.strip_edges()
	if not s.is_empty():
		return s
	if String(npc_id).is_empty():
		return "Talk"
	return "Talk to %s" % String(npc_id)


func apply_event(event_id: StringName, payload: Dictionary, progress: int) -> int:
	return super.apply_event(event_id, payload, progress)
