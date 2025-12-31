class_name NpcConfig
extends Resource

## Data-driven NPC definition (defaults + identity).
## Runtime state is still persisted via AgentRegistry/AgentsSave (AgentRecord).
##
## Primary use: solve "first spawn" for NPCs (seed missing records + initial placement).
## Secondary use: data-driven visuals (SpriteFrames / default animation).

@export var npc_id: StringName = &""

## Initial spawn placement:
## - NPC record will be seeded with current_level_id = initial_level_id
## - If initial_spawn_id != NONE and the level has a SpawnMarker for it, spawn there.
@export var initial_level_id: Enums.Levels = Enums.Levels.NONE
@export var initial_spawn_id: Enums.SpawnId = Enums.SpawnId.NONE

## Initial economy/inventory defaults.
@export var initial_money: int = 0
@export var initial_inventory: InventoryData = null

## Visual overrides (optional). Keeps us from needing per-NPC scenes.
@export var sprite_frames: SpriteFrames = null
@export var default_animation: StringName = &""

## Online movement (MVP): optional route to follow while level is loaded.
@export var move_speed: float = 22.0

## Keys are level ids, values are RouteIds.Id (enum).
## We resolve it to a stable StringName via `RouteIds.name(...)`.
@export var routes_by_level: Dictionary[Enums.Levels, RouteIds.Id] = {}

func is_valid() -> bool:
	return not String(npc_id).is_empty()

func get_route_id_for_level(level_id: Enums.Levels) -> RouteIds.Id:
	var rid: int = int(routes_by_level.get(level_id, -1))
	if rid < 0:
		return RouteIds.Id.NONE
	return rid as RouteIds.Id

func create_initial_record() -> AgentRecord:
	var rec := AgentRecord.new()
	rec.agent_id = npc_id
	rec.kind = Enums.AgentKind.NPC
	rec.current_level_id = initial_level_id
	rec.last_spawn_id = initial_spawn_id
	rec.money = int(initial_money)
	rec.inventory = initial_inventory
	return rec

