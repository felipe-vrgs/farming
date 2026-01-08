class_name QuestSave
extends Resource

## Increment when schema changes.
@export var version: int = 1

## Active quest progress: quest_id -> current step index (0-based).
@export var active_quests: Dictionary = {}

## Completed quest IDs.
@export var completed_quests: PackedStringArray = PackedStringArray()
