@tool
class_name RouteResource
extends Resource

## RouteResource (v1)
## - Decouples route geometry from level scenes (enables offline sampling).
## - Stores either:
##   - `points_world` (polyline in global/world coords for that level scene), or
##   - `curve_world` (Curve2D in world coords).
##
## Notes:
## - v1 focuses on deterministic sampling, not pathfinding/physics.
## Coordinate convention:
## - `points_world` / `curve_world` are stored as the agent's origin world positions
##   (`Node2D.global_position`).
## - `AgentRecord.last_world_pos` is also the origin world position.

## Optional: source level id for organization/debug.
@export var level_id: Enums.Levels = Enums.Levels.NONE

## Stable name for this route (human-readable; also used for file naming in bake tool).
@export var route_name: StringName = &""

## Default looping behavior (schedule steps can override via `loop_route`).
@export var loop_default: bool = true

## Optional tags for filtering/grouping.
@export var tags: PackedStringArray = PackedStringArray()

## Polyline representation (preferred for v1).
@export var points_world: PackedVector2Array = PackedVector2Array()

## Optional Curve2D representation.
@export var curve_world: Curve2D = null
