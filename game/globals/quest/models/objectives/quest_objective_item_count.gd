@tool
class_name QuestObjectiveItemCount
extends QuestObjective

## Counts items for a specific quest event stream (e.g. items_gained/items_sold/items_bought).
@export var event_id: StringName = &"items_gained"
@export var item_id: StringName = &""


func describe() -> String:
	var action := String(event_id)
	if action == "items_gained":
		action = "Gather"
	elif action == "items_sold":
		action = "Sell"
	elif action == "items_bought":
		action = "Buy"
	else:
		action = action.replace("_", " ").capitalize()
	if String(item_id).is_empty():
		return "%s (%d)" % [action, int(target_count)]
	return "%s %d %s" % [action, int(target_count), String(item_id)]


func apply_event(ev: StringName, payload: Dictionary, progress: int) -> int:
	var p := maxi(0, int(progress))
	if ev != event_id:
		return p
	if payload == null:
		return p
	var got: StringName = payload.get("item_id", &"")
	if not String(item_id).is_empty() and got != item_id:
		return p
	var delta_v: Variant = payload.get("count", 0)
	var delta := 0
	if delta_v is int:
		delta = int(delta_v)
	elif delta_v is float:
		delta = int(delta_v)
	delta = maxi(0, delta)
	return p + delta
