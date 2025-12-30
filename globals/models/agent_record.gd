class_name AgentRecord
extends Resource

@export var agent_id: StringName = &""
@export var kind: Enums.AgentKind = Enums.AgentKind.NONE
@export var current_level_id: Enums.Levels = Enums.Levels.NONE

@export var last_cell: Vector2i = Vector2i.ZERO
@export var last_world_pos: Vector2 = Vector2.ZERO

## Last "entry intent" used when an agent moved levels (for future spawn-on-load systems).
@export var last_spawn_id: Enums.SpawnId = Enums.SpawnId.NONE

## For queued/offline travel decisions.
@export var pending_level_id: Enums.Levels = Enums.Levels.NONE
@export var pending_spawn_id: Enums.SpawnId = Enums.SpawnId.NONE

func is_valid() -> bool:
	return not String(agent_id).is_empty()


