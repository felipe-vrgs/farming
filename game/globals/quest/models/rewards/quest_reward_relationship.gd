class_name QuestRewardRelationship
extends QuestReward

## Grants relationship progress to a specific NPC.
## Units are half-hearts: 2 units = 1 heart. Clamped by RelationshipManager (0..20).

@export var npc_id: StringName = &""
@export var delta_units: int = 2


func describe() -> String:
	if String(npc_id).is_empty():
		return "Relationship"
	return "Relationship: %s %s" % [String(npc_id), _format_delta(delta_units)]


func grant(_player: Node) -> void:
	if String(npc_id).is_empty():
		return
	if RelationshipManager == null:
		return
	RelationshipManager.add_units(npc_id, int(delta_units))


func _format_delta(units: int) -> String:
	var s := "+" if units >= 0 else "-"
	var absu := absi(int(units))
	var whole := absu / 2.0
	var half := absu % 2
	if half == 0:
		return "%s%d\u2665" % [s, whole]
	if whole == 0:
		return "%s\u00bd\u2665" % s
	return "%s%d\u00bd\u2665" % [s, whole]
