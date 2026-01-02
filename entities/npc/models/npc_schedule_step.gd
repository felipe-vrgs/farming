class_name NpcScheduleStep
extends Resource

enum Kind {
	HOLD = 0,
	ROUTE = 1,
	TRAVEL = 2,
}

## Daily schedule start time (0..1439).
@export_range(0, 1439, 1) var start_minute_of_day: int = 0

## Duration of this step in in-game minutes.
@export_range(1, 1440, 1) var duration_minutes: int = 60

@export var kind: Kind = Kind.HOLD

## "Where this step takes place" (for routing/holding).
@export var level_id: Enums.Levels = Enums.Levels.NONE

## ROUTE payload.
@export var route_res: RouteResource = null
## If false, the NPC completes the route once then stops (idles) until schedule changes.
@export var loop_route: bool = true

## TRAVEL payload.
@export var target_spawn_point: SpawnPointData = null
## Optional: route to walk before committing travel (online).
## If null, travel is committed immediately (teleport-style).
@export var exit_route_res: RouteResource = null

## Direction to face when holding or idling at end of route.
@export var facing_dir: Vector2 = Vector2.DOWN

func get_end_minute_of_day() -> int:
	return start_minute_of_day + max(1, duration_minutes)

func get_target_level_id() -> Enums.Levels:
	if target_spawn_point != null:
		return target_spawn_point.level_id
	return Enums.Levels.NONE

func is_valid() -> bool:
	if duration_minutes <= 0:
		return false
	match kind:
		Kind.ROUTE:
			return level_id != Enums.Levels.NONE and route_res != null
		Kind.TRAVEL:
			return target_spawn_point != null and target_spawn_point.is_valid()
		_:
			return true
