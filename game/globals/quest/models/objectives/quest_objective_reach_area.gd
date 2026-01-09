@tool
class_name QuestObjectiveReachArea
extends QuestObjectiveTimelineCompleted

## Player-facing “reach” objective that completes when a cutscene timeline ends.
## The timeline is the trigger; this objective exists to provide better UI text.

@export var area_name: String = ""


func describe() -> String:
	var s := display_text.strip_edges()
	if not s.is_empty():
		return s
	var a := area_name.strip_edges()
	if not a.is_empty():
		return "Reach %s" % a
	return "Reach destination"
