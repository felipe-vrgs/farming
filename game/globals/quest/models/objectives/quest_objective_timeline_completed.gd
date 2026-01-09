@tool
class_name QuestObjectiveTimelineCompleted
extends QuestObjective

## Completes when a specific Dialogic timeline finishes.
##
## This is the shared “trigger” mechanism. Player-facing objectives should customize
## `display_text` and/or override `describe()` for better UX.

@export var timeline_id: StringName = &""

## Player-facing text shown in quest panels, reward popups, etc.
@export var display_text: String = ""


func describe() -> String:
	var s := display_text.strip_edges()
	if not s.is_empty():
		return s
	if String(timeline_id).is_empty():
		return "Objective"
	# Fallback: show a readable form of the id.
	return String(timeline_id).replace("_", " ")


func apply_event(event_id: StringName, payload: Dictionary, progress: int) -> int:
	var p := maxi(0, int(progress))
	if event_id != &"timeline_completed":
		return p
	if payload == null:
		return p
	if String(timeline_id).is_empty():
		return p
	var completed_timeline: StringName = payload.get("timeline_id", &"")
	if completed_timeline == timeline_id or completed_timeline == &"cutscenes/" + timeline_id:
		return target_count
	return p
