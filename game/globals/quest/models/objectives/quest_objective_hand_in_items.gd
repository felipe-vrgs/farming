@tool
class_name QuestObjectiveHandInItems
extends QuestObjective

## Objective that is completed by handing items to a specific NPC (via interaction flow).
## Note: completion is driven by gameplay code (WorldGrid hand-in flow), not by quest events.

@export var npc_id: StringName = &""
@export var item_id: StringName = &""

## Optional cutscene to play after handing items.
## This is a cutscene id (no "cutscenes/" prefix). Example: &"starting_cutscene"
@export var cutscene_id: StringName = &""

## Optional player-facing override (used by quest UI). If empty, we generate a fallback.
@export var display_text: String = ""


func describe() -> String:
	var s := display_text.strip_edges()
	if not s.is_empty():
		return s

	var cnt := maxi(1, int(target_count))
	var item := String(item_id)
	var npc := String(npc_id)

	if item.is_empty():
		item = "items"
	if npc.is_empty():
		return "Hand %d %s" % [cnt, item]
	return "Hand %d %s to %s" % [cnt, item, npc]
