class_name LevelSave
extends Resource

## Increment when schema changes.
@export var version: int = 1

## Level ID.
@export var level_id: Enums.Levels = Enums.Levels.NONE

## Frieren house upgrade tier (shared with exterior).
@export var frieren_house_tier: int = 0

## Sparse list of cells we have state for.
@export var cells: Array[CellSnapshot] = []

## Deduped list of entities in this level.
@export var entities: Array[EntitySnapshot] = []
