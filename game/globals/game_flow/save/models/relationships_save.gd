class_name RelationshipsSave
extends Resource

## Increment when schema changes.
@export var version: int = 1

## Relationship values: npc_id(String) -> units(int, 0..20).
## Keys are stored as Strings for serialization friendliness.
@export var values: Dictionary = {}
