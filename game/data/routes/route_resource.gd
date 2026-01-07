@tool
class_name RouteResource
extends Resource

## RouteResource (v2)
## - Stores a sequence of WorldPoints, allowing routes to span multiple levels.

## Stable name for this route.
@export var route_name: StringName = &""

## Default looping behavior.
@export var loop_default: bool = true

## Route definition: sequence of WorldPoints.
@export var waypoints: Array[WorldPoint] = []

## Optional tags for filtering/grouping.
@export var tags: PackedStringArray = PackedStringArray()
