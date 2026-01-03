class_name DialogueSave
extends Resource

## Increment when schema changes.
@export var version: int = 1

## Snapshot of Dialogic.VAR dictionary.
## We capture the entire Dialogic variable state here.
@export var dialogic_variables: Dictionary = {}

## Track which timelines have been completed (for conditional logic).
## Example: { "npcs/frieren/greeting": true }
@export var completed_timelines: Dictionary = {}
