@tool
class_name SpawnPointData
extends WorldPoint

## SpawnPointData - data-driven spawn point definition.
##
## The resource itself is the identifier (via resource_path).
## Inherits level_id and position from WorldPoint.

## Optional human-readable name for debugging/editor.
@export var display_name: String = ""


func is_valid() -> bool:
	return level_id != Enums.Levels.NONE


## Get a unique key for this spawn point (resource path).
func get_key() -> String:
	return resource_path if not resource_path.is_empty() else ""
