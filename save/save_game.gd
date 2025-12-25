class_name SaveGame
extends Resource

## Increment this when the schema changes.
@export var version: int = 1

## World time.
@export var current_day: int = 1

## Sparse list of cells we have state for.
@export var cells: Array[CellSnapshot] = []

## Deduped list of grid entities.
@export var entities: Array[EntitySnapshot] = []


