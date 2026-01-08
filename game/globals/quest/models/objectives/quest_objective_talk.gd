class_name QuestObjectiveTalk
extends QuestObjective

@export var npc_id: StringName = &""
@export var timeline_id: StringName = &""


func describe() -> String:
	if not String(timeline_id).is_empty():
		if String(npc_id).is_empty():
			return "Complete timeline '%s'" % String(timeline_id)
		return "Talk to %s (timeline '%s')" % [String(npc_id), String(timeline_id)]

	if String(npc_id).is_empty():
		return "Talk"
	return "Talk to %s" % String(npc_id)


func apply_event(event_id: StringName, payload: Dictionary, progress: int) -> int:
	var p := maxi(0, int(progress))
	if payload == null:
		return p

	# Timeline-only completion: require an explicit timeline_id and complete only when it finishes.
	if event_id != &"timeline_completed":
		return p
	if String(timeline_id).is_empty():
		return p
	var completed_timeline: StringName = payload.get("timeline_id", &"")
	if completed_timeline == timeline_id:
		return target_count
	return p
