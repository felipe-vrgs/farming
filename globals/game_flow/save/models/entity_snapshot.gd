class_name EntitySnapshot
extends Resource

## PackedScene path, used to instantiate the entity on load (e.g. "res://entities/tree/tree.tscn").
@export var scene_path: String

## Stable id for editor-placed entities (used for reconciliation to avoid duplicates).
@export var persistent_id: StringName = &""

## Primary cell for this entity (multi-cell entities can derive occupied cells from their shape).
@export var grid_pos: Vector2i

## Enums.EntityType (stored redundantly for convenience/debugging).
@export var entity_type: int = 0

## Arbitrary entity state (HP, growth days, variant, etc).
@export var state: Dictionary = {}
