@tool
class_name NpcScheduleStep
extends Resource

enum Kind {
	HOLD = 0,
	ROUTE = 1,
	IDLE_AROUND = 2,
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
## If true, when this ROUTE finishes (and Loop is OFF), immediately start the next ROUTE step.
## Default OFF to avoid implicit chaining surprises.
@export var chain_next_route: bool = false

## HOLD payload: where the NPC should be while holding.
@export var hold_spawn_point: SpawnPointData = null

## Direction to face when holding or idling at end of route.
@export var facing_dir: Vector2 = Vector2.DOWN

## IDLE_AROUND payload.
@export var idle_points: Array[NpcIdleAroundPoint] = []
@export var idle_random: bool = false


func get_end_minute_of_day() -> int:
	return start_minute_of_day + max(1, duration_minutes)


func is_valid() -> bool:
	var ok := true
	if duration_minutes <= 0:
		ok = false
	else:
		match kind:
			Kind.ROUTE:
				ok = route_res != null
			Kind.HOLD:
				ok = hold_spawn_point != null
			Kind.IDLE_AROUND:
				ok = false
				for p in idle_points:
					if p != null and p.is_valid():
						ok = true
						break
			_:
				ok = true
	return ok
