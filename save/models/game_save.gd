class_name GameSave
extends Resource

## Increment when schema changes.
@export var version: int = 1

## Global time (shared across all levels).
@export var current_day: int = 1

## Which level should be loaded on continue.
@export var active_level_id: StringName = &""


