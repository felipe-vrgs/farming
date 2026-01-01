class_name AgentRecord
extends Resource

@export var agent_id: StringName = &""
@export var kind: Enums.AgentKind = Enums.AgentKind.NONE
@export var current_level_id: Enums.Levels = Enums.Levels.NONE

## Last known grid cell for this agent. Negative values mean "unset".
@export var last_cell: Vector2i = Vector2i(-1, -1)
@export var last_world_pos: Vector2 = Vector2.ZERO

## Last spawn point used when agent moved levels (resource path).
@export var last_spawn_point_path: String = ""

## If true, the next time the agent is materialized in its current level, the spawner should
## place it using last_spawn_point_path instead of last_world_pos.
@export var needs_spawn_marker: bool = false

## For queued/offline travel decisions.
@export var pending_level_id: Enums.Levels = Enums.Levels.NONE
@export var pending_spawn_point_path: String = ""
## TravelIntent deadline: absolute minute when we should force-commit if still pending.
## -1 means "no deadline".
@export var pending_expires_absolute_minute: int = -1

## Agent-owned economy/inventory (global across levels).
@export var money: int = 0
@export var inventory: InventoryData = null

## Player-ish equipment/selection (also useful for NPC equipment later).
@export var selected_tool_id: StringName = &""
@export var selected_seed_id: StringName = &""

## Offline simulation bookkeeping (v2):
## Used to keep offline path motion continuous (avoid snapping to route start).
@export var last_sim_absolute_minute: int = -1
@export var last_sim_route_key: StringName = &""
@export var last_sim_route_distance: float = 0.0

func is_valid() -> bool:
	return not String(agent_id).is_empty()

func get_last_spawn_point() -> SpawnPointData:
	if last_spawn_point_path.is_empty():
		return null
	return load(last_spawn_point_path) as SpawnPointData

func get_pending_spawn_point() -> SpawnPointData:
	if pending_spawn_point_path.is_empty():
		return null
	return load(pending_spawn_point_path) as SpawnPointData
