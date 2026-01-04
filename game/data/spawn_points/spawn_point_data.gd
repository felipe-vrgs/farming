@tool
class_name SpawnPointData
extends Resource

## SpawnPointData - data-driven spawn point definition.
##
## The resource itself is the identifier (via resource_path).
## No enum needed - just reference the .tres file directly.
@export var level_id: Enums.Levels = Enums.Levels.NONE
@export var position: Vector2 = Vector2.ZERO

## Optional human-readable name for debugging/editor.
@export var display_name: String = ""


func is_valid() -> bool:
	return level_id != Enums.Levels.NONE


## Get a unique key for this spawn point (resource path).
func get_key() -> String:
	return resource_path if not resource_path.is_empty() else ""
