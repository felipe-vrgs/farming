@tool
class_name SpawnCatalog
extends Resource

## SpawnCatalog
## Central, data-driven spawn configuration:
## - player start spawn
## - player bed spawn (forced sleep)
## - per-level default spawns (used as fallback when no explicit spawn is provided)

@export var player_spawn: SpawnPointData = null
@export var player_bed: SpawnPointData = null

## One spawn per level. The SpawnPointData.level_id field is used as the key.
@export var level_default_spawns: Array[SpawnPointData] = []


func get_default_spawn_for_level(level_id: Enums.Levels) -> SpawnPointData:
	for sp in level_default_spawns:
		if sp == null:
			continue
		if sp.level_id == level_id:
			return sp
	return null
