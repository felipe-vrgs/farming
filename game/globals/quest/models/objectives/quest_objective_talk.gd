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

	# Handle specific timeline completion (generic)
	if event_id == &"timeline_completed":
		if not String(timeline_id).is_empty():
			var completed_timeline: StringName = payload.get("timeline_id", &"")
			# If we require a specific timeline, check it.
			# Also ensure npc_id is empty if we are relying on this event (strictness).
			if completed_timeline == timeline_id and String(npc_id).is_empty():
				return target_count
		return p

	if event_id == &"talked_to_npc":
		var got_npc: StringName = payload.get("npc_id", &"")
		var got_timeline: StringName = payload.get("timeline_id", &"")

		var timeline_matches := String(timeline_id).is_empty() or got_timeline == timeline_id
		var npc_matches := String(npc_id).is_empty() or got_npc == npc_id

		if timeline_matches and npc_matches:
			return target_count

	return p
