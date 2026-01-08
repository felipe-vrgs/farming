class_name QuestSave
extends Resource

## Increment when schema changes.
@export var version: int = 2

## Active quest progress: quest_id -> current step index (0-based).
@export var active_quests: Dictionary = {}

## Completed quest IDs.
@export var completed_quests: PackedStringArray = PackedStringArray()

## Optional objective progress: quest_id -> Dictionary(step_idx -> progress_int)
## Keys are stored as Strings for serialization friendliness.
@export var objective_progress: Dictionary = {}
