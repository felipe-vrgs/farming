class_name QuestStep
extends Resource

## A single step in a quest sequence.

@export_multiline var description: String = ""

## Optional objective that can auto-advance this step based on quest events.
## If null, the step must be advanced manually (or via dialogue/cutscene scripts).
@export var objective: QuestObjective = null

## Rewards granted immediately when this step is completed.
@export var step_rewards: Array = []
