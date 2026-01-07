@tool
class_name WorldPoint
extends Resource

## WorldPoint - a position in a specific level.
##
## Used for multi-level routing and spawn points.

@export var level_id: Enums.Levels = Enums.Levels.NONE
@export var position: Vector2 = Vector2.ZERO


func _to_string() -> String:
	return "WorldPoint(level=%s, pos=%s)" % [level_id, position]
