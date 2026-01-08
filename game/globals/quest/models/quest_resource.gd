class_name QuestResource
extends Resource

## Definition of a quest and its steps.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""

## The sequence of steps for this quest.
## The quest tracks current step index (0-based).
@export var steps: Array[QuestStep] = []
