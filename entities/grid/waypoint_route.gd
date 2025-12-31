@tool
extends Node2D

## Simple route defined by Marker2D children.
## This is intentionally lightweight for iteration; we can swap to Path2D later.

@export var route_id: RouteIds.Id = RouteIds.Id.NONE

func _enter_tree() -> void:
	add_to_group(Groups.name(Groups.Id.ROUTES))

func get_waypoints_global() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for c in get_children():
		if c is Marker2D:
			out.append((c as Marker2D).global_position)
	return out

