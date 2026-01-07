class_name NpcScheduleStep
extends Resource

enum Kind {
	HOLD = 0,
	ROUTE = 1,
}

## Daily schedule start time (0..1439).
@export_range(0, 1439, 1) var start_minute_of_day: int = 0

## Duration of this step in in-game minutes.
@export_range(1, 1440, 1) var duration_minutes: int = 60

@export var kind: Kind = Kind.HOLD

## ROUTE payload.
@export var route_res: RouteResource = null
## If false, the NPC completes the route once then stops (idles) until schedule changes.
@export var loop_route: bool = true

## HOLD payload: where the NPC should be while holding.
@export var hold_spawn_point: SpawnPointData = null

## Direction to face when holding or idling at end of route.
@export var facing_dir: Vector2 = Vector2.DOWN


func get_end_minute_of_day() -> int:
	return start_minute_of_day + max(1, duration_minutes)


func is_valid() -> bool:
	if duration_minutes <= 0:
		return false
	match kind:
		Kind.ROUTE:
			return route_res != null
		Kind.HOLD:
			return hold_spawn_point != null
		_:
			return true
