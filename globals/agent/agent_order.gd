class_name AgentOrder
extends RefCounted

## AgentOrder - represents what an agent should do this tick.

enum Action {
	IDLE,
	MOVE_TO,
}

enum BlockReason {
	NONE,
	PLAYER,
	OBSTACLE,
	DIALOGUE,
	INTERACTION,
}

var agent_id: StringName = &""
var action: Action = Action.IDLE

## Next waypoint to walk to (world position).
var target_position: Vector2 = Vector2.ZERO

## Direction to face when idle.
var facing_dir: Vector2 = Vector2.DOWN

## Route context for debugging.
var is_on_route: bool = false
var route_key: StringName = &""
var route_progress: float = 0.0

## Travel metadata - set when NPC needs to leave the level.
var is_traveling: bool = false
var travel_spawn_point: SpawnPointData = null
var travel_deadline_abs: int = -1


func _to_string() -> String:
	var action_str := "IDLE" if action == Action.IDLE else "MOVE_TO"
	return "AgentOrder(%s, %s, pos=%s)" % [agent_id, action_str, target_position]
