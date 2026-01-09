@tool
class_name QuestResource
extends Resource

## Definition of a quest and its steps.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""

## If true, this quest is unlocked at game start (new game).
## If true AND `auto_start_when_unlocked`, it will also start automatically on new game.
@export var unlock_at_game_start: bool = false

## Optional prerequisite quest. If set, this quest becomes unlocked when that quest completes.
@export var unlock_from_quest: StringName = &""

## If true, QuestManager auto-starts this quest when it becomes unlocked.
@export var auto_start_when_unlocked: bool = true

## The sequence of steps for this quest.
## The quest tracks current step index (0-based).
@export var steps: Array[QuestStep] = []

## Rewards granted when the quest is completed (after the final step).
@export var completion_rewards: Array = []


func is_unlocked(completed_ids: Dictionary) -> bool:
	if unlock_at_game_start:
		return true
	if String(unlock_from_quest).is_empty():
		return true
	if completed_ids == null:
		return false
	return bool(completed_ids.get(unlock_from_quest, false))


func validate(known_quest_ids: Dictionary = {}) -> PackedStringArray:
	var issues := PackedStringArray()
	if String(id).is_empty():
		issues.append("QuestResource.id is empty.")
	if steps.is_empty():
		issues.append("QuestResource.steps is empty.")
	for i in range(steps.size()):
		if steps[i] == null:
			issues.append("QuestResource.steps[%d] is null." % i)
	if not String(unlock_from_quest).is_empty():
		if unlock_from_quest == id:
			issues.append("unlock_from_quest cannot reference itself.")
		if known_quest_ids is Dictionary and not known_quest_ids.has(unlock_from_quest):
			issues.append("unlock_from_quest '%s' not found." % String(unlock_from_quest))
	return issues
