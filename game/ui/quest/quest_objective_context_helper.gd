class_name QuestObjectiveContextHelper
extends RefCounted

## Small helper to map quest objectives to a short "action/context" label
## suitable for compact UI (e.g. RewardPopup).


static func get_action_label(objective: QuestObjective) -> String:
	if objective == null:
		return ""

	if objective is QuestObjectiveItemCount:
		var o := objective as QuestObjectiveItemCount
		return _label_for_item_count_event(o.event_id)

	if objective is QuestObjectiveEntityDepleted:
		# "Deplete" reads like "Destroy/Cut/Mine" depending on kind, but keep it generic for now.
		return "Deplete"

	if objective is QuestObjectiveTalk:
		return "Talk"

	# Fallback: derive from describe() first token, otherwise class name.
	if objective.has_method("describe"):
		var d := String(objective.call("describe")).strip_edges()
		if not d.is_empty():
			var parts := d.split(" ", false, 2)
			if parts.size() > 0:
				return String(parts[0]).capitalize()

	return ""


static func _label_for_item_count_event(event_id: StringName) -> String:
	match String(event_id):
		"items_gained":
			return "Gather"
		"items_sold":
			return "Sell"
		"items_bought":
			return "Buy"
		_:
			return String(event_id).replace("_", " ").capitalize()
