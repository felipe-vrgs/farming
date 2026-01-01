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

func is_valid() -> bool:
	# Allow single-point routes (useful for "exit routes" that just target a portal marker).
	return get_point_count() >= 1

func get_point_count() -> int:
	if curve_world != null and curve_world.point_count >= 1:
		return int(curve_world.point_count)
	return int(points_world.size())

func sample_world_pos(progress: float, looped: bool = false) -> Vector2:
	# Returns an approximate position along the route for a normalized progress [0..1].
	# - If looped, wrap progress (so 1.0 == 0.0).
	# - If not looped, clamp to ends.
	if not is_valid():
		return Vector2.ZERO

	var t := float(progress)
	if looped:
		t = fposmod(t, 1.0)
	else:
		t = clampf(t, 0.0, 1.0)

	if curve_world != null and curve_world.point_count >= 2:
		# Prefer baked sampling for stable distribution along length.
		var baked := curve_world.get_baked_points()
		if baked.size() >= 2:
			return _sample_polyline(PackedVector2Array(baked), t, looped)
		# Fallback: sample by point index.
		return curve_world.get_point_position(int(round(t * float(curve_world.point_count - 1))))
	if curve_world != null and curve_world.point_count == 1:
		return curve_world.get_point_position(0)

	if points_world.size() == 1:
		return points_world[0]
	return _sample_polyline(points_world, t, looped)

func get_length(looped: bool = false) -> float:
	if not is_valid():
		return 0.0
	if curve_world != null and curve_world.point_count >= 2:
		var baked := curve_world.get_baked_points()
		if baked.size() >= 2:
			return _polyline_length(PackedVector2Array(baked), looped)
	if points_world.size() >= 2:
		return _polyline_length(points_world, looped)
	return 0.0

func sample_world_pos_by_distance(distance: float, looped: bool = false) -> Vector2:
	# Sample a point by distance along the route.
	# - If looped: wrap distance across full loop length.
	# - If not looped: clamp distance to [0..length].
	if not is_valid():
		return Vector2.ZERO

	if curve_world != null and curve_world.point_count >= 2:
		var baked := curve_world.get_baked_points()
		if baked.size() >= 2:
			return _sample_polyline_by_distance(PackedVector2Array(baked), distance, looped)
	if curve_world != null and curve_world.point_count == 1:
		return curve_world.get_point_position(0)

	if points_world.size() == 1:
		return points_world[0]
	return _sample_polyline_by_distance(points_world, distance, looped)

func project_distance_world(pos: Vector2, looped: bool = false) -> float:
	# Returns the distance-from-start along this route whose point is closest to `pos`.
	# Useful for "resume from wherever you are" behavior in offline simulation.
	if not is_valid():
		return 0.0
	if curve_world != null and curve_world.point_count >= 2:
		var baked := curve_world.get_baked_points()
		if baked.size() >= 2:
			return _project_polyline_distance(PackedVector2Array(baked), pos, looped)
	if points_world.size() >= 2:
		return _project_polyline_distance(points_world, pos, looped)
	return 0.0

static func _sample_polyline(points: PackedVector2Array, t: float, looped: bool) -> Vector2:
	if points.size() == 0:
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]

	var total := _polyline_length(points, looped)
	if total <= 0.001:
		return points[0]

	var target := total * t
	var acc := 0.0

	var n := int(points.size())
	var seg_count := n if looped else (n - 1)
	for i in range(seg_count):
		var a := points[i]
		var b := points[(i + 1) % n]
		var seg := a.distance_to(b)
		if seg <= 0.001:
			continue
		if acc + seg >= target:
			var local := (target - acc) / seg
			return a.lerp(b, clampf(local, 0.0, 1.0))
		acc += seg

	# If we didn't hit (e.g. due to float errors), return end.
	return points[0] if looped else points[n - 1]

static func _polyline_length(points: PackedVector2Array, looped: bool) -> float:
	if points.size() < 2:
		return 0.0
	var total := 0.0
	var n := int(points.size())
	var seg_count := n if looped else (n - 1)
	for i in range(seg_count):
		total += points[i].distance_to(points[(i + 1) % n])
	return total

static func _sample_polyline_by_distance(
	points: PackedVector2Array,
	distance: float,
	looped: bool
) -> Vector2:
	if points.size() == 0:
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]

	var total := _polyline_length(points, looped)
	if total <= 0.001:
		return points[0]

	var d := float(distance)
	if looped:
		d = fposmod(d, total)
	else:
		d = clampf(d, 0.0, total)

	var acc := 0.0
	var n := int(points.size())
	var seg_count := n if looped else (n - 1)
	for i in range(seg_count):
		var a := points[i]
		var b := points[(i + 1) % n]
		var seg := a.distance_to(b)
		if seg <= 0.001:
			continue
		if acc + seg >= d:
			var local := (d - acc) / seg
			return a.lerp(b, clampf(local, 0.0, 1.0))
		acc += seg

	return points[0] if looped else points[n - 1]

static func _project_polyline_distance(
	points: PackedVector2Array,
	pos: Vector2,
	looped: bool
) -> float:
	if points.size() < 2:
		return 0.0
	var best_d2 := INF
	var best_s := 0.0
	var acc := 0.0
	var n := int(points.size())
	var seg_count := n if looped else (n - 1)
	for i in range(seg_count):
		var a := points[i]
		var b := points[(i + 1) % n]
		var ab := b - a
		var ab_len2 := ab.length_squared()
		var t := 0.0
		if ab_len2 > 0.000001:
			t = clampf((pos - a).dot(ab) / ab_len2, 0.0, 1.0)
		var p := a + ab * t
		var d2 := pos.distance_squared_to(p)
		if d2 < best_d2:
			best_d2 = d2
			best_s = acc + a.distance_to(p)
		acc += a.distance_to(b)
	return best_s

