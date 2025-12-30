class_name AgentRecord
extends Resource

@export var agent_id: StringName = &""
@export var kind: Enums.AgentKind = Enums.AgentKind.NONE
@export var current_level_id: Enums.Levels = Enums.Levels.NONE

## Last known grid cell for this agent. Negative values mean "unset".
@export var last_cell: Vector2i = Vector2i(-1, -1)
@export var last_world_pos: Vector2 = Vector2.ZERO

## Last "entry intent" used when an agent moved levels (for future spawn-on-load systems).
@export var last_spawn_id: Enums.SpawnId = Enums.SpawnId.NONE

## For queued/offline travel decisions.
@export var pending_level_id: Enums.Levels = Enums.Levels.NONE
@export var pending_spawn_id: Enums.SpawnId = Enums.SpawnId.NONE

## Agent-owned economy/inventory (global across levels).
@export var money: int = 0
@export var inventory: InventoryData = null

## Player-ish equipment/selection (also useful for NPC equipment later).
@export var selected_tool_id: StringName = &""
@export var selected_seed_id: StringName = &""

func is_valid() -> bool:
	return not String(agent_id).is_empty()


