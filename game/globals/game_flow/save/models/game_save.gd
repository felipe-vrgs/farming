class_name GameSave
extends Resource

## Increment when schema changes.
@export var version: int = 1

## Global time (shared across all levels).
@export var current_day: int = 1

## Global clock time-of-day (minute index since start of day).
## Range: [0..TimeManager.MINUTES_PER_DAY-1]
@export var minute_of_day: int = 0

## Which level should be loaded on continue.
@export var active_level_id: Enums.Levels = Enums.Levels.NONE

## Global upgrade tiers (e.g., house upgrade tiers).
@export var tiers: Dictionary = {}
