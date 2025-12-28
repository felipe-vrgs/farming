class_name LevelSave
extends Resource

## Increment when schema changes.
@export var version: int = 1

@export var level_id: StringName = &""

## Player position saved per-level (exact, no cell math yet).
@export var player_pos: Vector2 = Vector2.ZERO

## Sparse list of cells we have state for.
@export var cells: Array[CellSnapshot] = []

## Deduped list of entities in this level.
@export var entities: Array[EntitySnapshot] = []


