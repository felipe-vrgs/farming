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

## Agent-owned economy/inventory (global across levels).
@export var money: int = 0
@export var inventory: InventoryData = null

## Player-ish equipment/selection (also useful for NPC equipment later).
@export var selected_tool_id: StringName = &""
@export var selected_seed_id: StringName = &""

## Player appearance & equipment (visuals).
@export var appearance: CharacterAppearance = null
@export var equipment: Resource = null

## Player stamina/energy (per-day).
## NOTE: max energy is currently driven by the Player's EnergyComponent export/config.
@export var energy_current: float = -1.0
@export var energy_forced_wakeup_pending: bool = false

## Last facing direction (Vector2.DOWN, Vector2.UP, etc.)
@export var facing_dir: Vector2 = Vector2.DOWN


func is_valid() -> bool:
	return not String(agent_id).is_empty()


func get_last_spawn_point() -> SpawnPointData:
	if last_spawn_point_path.is_empty():
		return null
	return load(last_spawn_point_path) as SpawnPointData
