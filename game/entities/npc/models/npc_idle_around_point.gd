@tool
class_name NpcIdleAroundPoint
extends Resource

## NpcIdleAroundPoint - one target used by IDLE_AROUND schedule steps.

@export var spawn_point: SpawnPointData = null
@export_range(0, 1440, 1) var hold_minutes: int = 0
@export var facing_dir: Vector2 = Vector2.DOWN


func is_valid() -> bool:
	return spawn_point != null and spawn_point.is_valid()
