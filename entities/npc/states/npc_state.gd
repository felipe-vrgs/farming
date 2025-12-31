class_name NpcState
extends State

const _MOVE_EPS := 0.1
const _WAYPOINT_EPS := 2.0

var npc: NPC
var npc_config: NpcConfig

func bind_parent(new_parent: Node) -> void:
	super.bind_parent(new_parent)
	if new_parent is NPC:
		npc = new_parent
		npc_config = npc.npc_config

func enter() -> void:
	super.enter()
	# Refresh config in case it changed (unlikely but good practice)
	if npc:
		npc_config = npc.npc_config

func get_active_level_id() -> Enums.Levels:
	return GameManager.get_active_level_id() if GameManager != null else Enums.Levels.NONE

func get_active_route() -> RouteResource:
	# Schedule-driven only: states only follow an explicitly selected route.
	return npc.route_override_res if npc != null else null

func get_active_route_waypoints_global() -> Array[Vector2]:
	var r := get_active_route()
	if r == null or not r.is_valid():
		return []
	# RouteResource points are stored in world coords.
	# We return Array[Vector2] because existing state logic expects it.
	var out: Array[Vector2] = []
	if r.curve_world != null and r.curve_world.point_count >= 2:
		var baked := r.curve_world.get_baked_points()
		for p in baked:
			out.append(p)
	elif r.points_world.size() > 0:
		for p in r.points_world:
			out.append(p)
	return out

func find_nearest_waypoint_index(waypoints: Array[Vector2], pos: Vector2) -> int:
	if waypoints.is_empty():
		return 0
	var best_i := 0
	var best_d2 := INF
	for i in range(waypoints.size()):
		var d2 := pos.distance_squared_to(waypoints[i])
		if d2 < best_d2:
			best_d2 = d2
			best_i = i
	return best_i

func would_collide(motion: Vector2) -> bool:
	if npc == null:
		return false
	if npc.route_blocked_by_player:
		return true
	# `test_move` checks without actually moving.
	return npc.test_move(npc.global_transform, motion)

## Request the correct animation for the given motion vector.
## Unlike Player, we emit the fully-directed animation name (e.g. "move_left"),
## so the NPC host stays dumb and just plays what it's told.
func request_animation_for_motion(v: Vector2) -> void:
	if npc == null:
		return

	# Persist facing direction on the host for cross-state continuity.
	if v.length() > _MOVE_EPS:
		npc.facing_dir = v

	var moving := v.length() > _MOVE_EPS
	var prefix := &"move" if moving else &"idle"

	var dir: Vector2 = npc.facing_dir
	if dir.length() <= _MOVE_EPS:
		dir = Vector2.DOWN

	var anim := _dir_anim_name(prefix, dir)
	if not String(anim).is_empty():
		animation_change_requested.emit(anim)

func _dir_anim_name(prefix: StringName, dir: Vector2) -> StringName:
	# Supports either "idle_front/move_front" directional sets,
	# or a single "idle/move" animation if present.
	if npc != null and npc.sprite != null and npc.sprite.sprite_frames != null:
		if npc.sprite.sprite_frames.has_animation(prefix):
			return prefix

	if abs(dir.x) > abs(dir.y):
		if dir.x >= 0.0:
			return StringName("%s_right" % String(prefix))
		return StringName("%s_left" % String(prefix))
	if dir.y >= 0.0:
		return StringName("%s_front" % String(prefix))
	return StringName("%s_back" % String(prefix))

