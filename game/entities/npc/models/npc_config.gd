class_name NpcConfig
extends Resource

## Data-driven NPC definition (defaults + identity).
## Runtime state is still persisted via AgentRegistry/AgentsSave (AgentRecord).

@export var npc_id: StringName = &""

## Initial spawn placement.
@export var initial_spawn_point: SpawnPointData = null

## Initial economy/inventory defaults.
@export var initial_money: int = 0
@export var initial_inventory: InventoryData = null

## Visual overrides (optional). Keeps us from needing per-NPC scenes.
@export var sprite_frames: SpriteFrames = null
@export var default_animation: StringName = &""

## Online movement (MVP): optional route to follow while level is loaded.
@export var move_speed: float = 22.0

## Daily schedule (v1). If set, the NPC uses this instead of "always follow route".
@export var schedule: NpcSchedule = null

## Dialogue ID
@export var dialogue_id: StringName = &""

## Whether interacting opens the Shop UI (instead of dialogue).
@export var is_shopkeeper: bool = false


func is_valid() -> bool:
	return not String(npc_id).is_empty()


func create_initial_record() -> AgentRecord:
	var rec := AgentRecord.new()
	rec.agent_id = npc_id
	rec.kind = Enums.AgentKind.NPC
	if initial_spawn_point != null:
		rec.current_level_id = initial_spawn_point.level_id
		rec.last_spawn_point_path = initial_spawn_point.resource_path
		# Ensure first-time spawn never defaults to (0,0).
		rec.last_world_pos = initial_spawn_point.position
		# Place by spawn marker on first materialization.
		rec.needs_spawn_marker = true
	rec.money = int(initial_money)
	rec.inventory = initial_inventory
	return rec
