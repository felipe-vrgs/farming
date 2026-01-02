class_name AgentSpawner
extends Node

## AgentSpawner - spawns/despawns agents based on AgentRegistry records.
## Manages lifecycle of runtime nodes.

const _PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const _NPC_SCENE: PackedScene = preload("res://entities/npc/npc.tscn")

const _NPC_CONFIGS_DIR := "res://entities/npc/configs"
const _NPC_CONFIG_SCRIPT: Script = preload("res://entities/npc/models/npc_config.gd")

## Default spawn points per level (for new game / fallback)
const _DEFAULT_SPAWN_POINTS: Dictionary = {
	Enums.Levels.ISLAND: "res://data/spawn_points/island/player_spawn.tres",
	Enums.Levels.FRIEREN_HOUSE: "res://data/spawn_points/frieren_house/entry_from_island.tres",
}

var registry: AgentRegistry

## StringName npc_id -> NpcConfig
var _npc_configs: Dictionary[StringName, NpcConfig] = {}

## StringName agent_id -> Node (non-player agents only)
var _spawned_agents: Dictionary[StringName, Node] = {}

func setup(r: AgentRegistry) -> void:
	assert(r != null, "AgentSpawner: Registry must be provided")
	registry = r

func _ready() -> void:
	_reload_npc_configs()

func _reload_npc_configs() -> void:
	_npc_configs.clear()
	var dir := DirAccess.open(_NPC_CONFIGS_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var filename := dir.get_next()
		if filename.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not filename.ends_with(".tres"):
			continue
		var path := _NPC_CONFIGS_DIR + "/" + filename
		var res := load(path)
		if res is NpcConfig and (res as Resource).get_script() == _NPC_CONFIG_SCRIPT:
			var cfg := res as NpcConfig
			if not cfg.is_valid():
				continue
			_npc_configs[cfg.npc_id] = cfg
	dir.list_dir_end()

func get_npc_config(npc_id: StringName) -> NpcConfig:
	return _npc_configs.get(npc_id) as NpcConfig

func get_spawned_agent_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for agent_id in _spawned_agents.keys():
		out.append(agent_id)
	return out

func sync_all(lr: LevelRoot = null, fallback_spawn_point: SpawnPointData = null) -> void:
	if lr == null:
		return
	sync_player_on_level_loaded(lr, fallback_spawn_point)
	sync_agents_for_active_level(lr)

#region Player

func seed_player_for_new_game(lr: LevelRoot = null, spawn_point: SpawnPointData = null) -> Player:
	if lr == null:
		return null
	registry.set_runtime_capture_enabled(false)

	# Use default spawn point for level if none provided
	var sp := spawn_point
	if sp == null:
		sp = _get_default_spawn_point(lr.level_id)

	var p := _spawn_or_move_player_to_spawn(lr, sp)
	if p == null:
		registry.set_runtime_capture_enabled(true)
		return null

	registry.capture_record_from_node(p)
	registry.set_runtime_capture_enabled(true)
	return p

func sync_player_on_level_loaded(
	lr: LevelRoot = null,
	fallback_spawn_point: SpawnPointData = null
) -> Player:
	if lr == null:
		return null
	registry.set_runtime_capture_enabled(false)

	var rec: AgentRecord = _get_player_record()
	var p := _get_player_node()
	var placed_by_marker := false

	if rec != null and _should_place_by_spawn_marker(rec):
		var sp := rec.get_last_spawn_point()
		if sp != null and sp.is_valid():
			p = _spawn_player_at_pos(lr, sp.position)
			placed_by_marker = true
			rec.needs_spawn_marker = false
		else:
			p = _spawn_player_at_pos(lr, rec.last_world_pos)
	elif rec != null:
		var pos := rec.last_world_pos
		# Guard against uninitialized records producing (0,0) spawns.
		# Only treat (0,0) as invalid if the record also has no meaningful cell/spawn marker.
		var has_cell := rec.last_cell != Vector2i(-1, -1)
		if pos == Vector2.ZERO and not has_cell and rec.last_spawn_point_path.is_empty():
			var sp := fallback_spawn_point
			if sp == null:
				sp = _get_default_spawn_point(lr.level_id)
			p = _spawn_or_move_player_to_spawn(lr, sp)
			placed_by_marker = true
		else:
			p = _spawn_player_at_pos(lr, pos)
	else:
		# No record yet - use fallback or default spawn point
		var sp := fallback_spawn_point
		if sp == null:
			sp = _get_default_spawn_point(lr.level_id)
		p = _spawn_or_move_player_to_spawn(lr, sp)
		placed_by_marker = true

	if p == null:
		registry.set_runtime_capture_enabled(true)
		return null

	if rec != null:
		registry.apply_record_to_node(p, false)

	if placed_by_marker or rec == null:
		registry.capture_record_from_node(p)
		if rec != null:
			registry.upsert_record(rec)

	registry.set_runtime_capture_enabled(true)
	return p

func _get_player_record() -> AgentRecord:
	# Preferred stable id.
	var rec := registry.get_record(&"player") as AgentRecord
	if rec != null:
		return rec
	# Fallback for older saves: find the first PLAYER record.
	for r in registry.list_records():
		if r != null and r.kind == Enums.AgentKind.PLAYER:
			return r
	return null

func _get_player_node() -> Player:
	var nodes := get_tree().get_nodes_in_group(Groups.PLAYER)
	if nodes.is_empty():
		return null
	return nodes[0] as Player

func _spawn_player_at_pos(lr: LevelRoot, pos: Vector2) -> Player:
	if lr == null:
		return null

	var existing := _get_player_node()
	if existing != null:
		existing.global_position = pos
		return existing

	var node := _PLAYER_SCENE.instantiate()
	if not (node is Player):
		node.queue_free()
		return null

	var p := node as Player
	p.global_position = pos
	lr.get_entities_root().add_child(p)
	return p

func _spawn_or_move_player_to_spawn(lr: LevelRoot, spawn_point: SpawnPointData) -> Player:
	if lr == null:
		return null

	var pos := Vector2.ZERO
	if spawn_point != null and spawn_point.is_valid():
		pos = spawn_point.position
	return _spawn_player_at_pos(lr, pos)

func _get_default_spawn_point(level_id: Enums.Levels) -> SpawnPointData:
	var path: String = _DEFAULT_SPAWN_POINTS.get(level_id, "")
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("AgentSpawner: Default spawn point not found: %s" % path)
		return null
	return load(path) as SpawnPointData

#endregion

#region NPCs

func capture_spawned_agents() -> void:
	for agent_id in _spawned_agents.keys():
		var node = _spawned_agents.get(agent_id)
		if node == null or not is_instance_valid(node) or not (node is Node):
			continue
		registry.capture_record_from_node(node as Node)

func sync_agents_for_active_level(lr: LevelRoot = null) -> void:
	if lr == null:
		return
	var active_level_id: Enums.Levels = lr.level_id
	_seed_missing_npc_records()
	registry.set_runtime_capture_enabled(false)

	# Compute desired agent set
	var desired: Dictionary[StringName, AgentRecord] = {}
	for rec in registry.list_records():
		if rec == null or rec.kind == Enums.AgentKind.PLAYER:
			continue
		if rec.current_level_id != active_level_id:
			continue
		desired[rec.agent_id] = rec

	# Prune stale entries
	for agent_id in _spawned_agents.keys():
		var node = _spawned_agents.get(agent_id)
		if node == null or not is_instance_valid(node):
			_spawned_agents.erase(agent_id)

	# Despawn agents that left
	for agent_id in _spawned_agents.keys():
		if desired.has(agent_id):
			continue
		var node = _spawned_agents.get(agent_id)
		if node != null and is_instance_valid(node) and (node is Node):
			registry.capture_record_from_node(node as Node)
			(node as Node).queue_free()
		_spawned_agents.erase(agent_id)

	# Spawn missing agents
	for agent_id in desired.keys():
		if _spawned_agents.has(agent_id):
			continue
		var rec: AgentRecord = desired[agent_id]
		var node := _spawn_npc(rec, lr)
		if node != null:
			_spawned_agents[agent_id] = node

	registry.set_runtime_capture_enabled(true)

func _spawn_npc(rec: AgentRecord, lr: LevelRoot) -> Node2D:
	if rec == null or lr == null:
		return null

	var node := _NPC_SCENE.instantiate()
	if not (node is Node2D):
		node.queue_free()
		return null

	var n2 := node as Node2D

	# Configure NPC
	var npc_cfg := get_npc_config(rec.agent_id)
	if npc_cfg != null and n2 is NPC:
		(n2 as NPC).set_npc_config(npc_cfg)

	# Set identity early
	var direct_ac := n2.get_node_or_null(NodePath("Components/AgentComponent"))
	if direct_ac is AgentComponent:
		(direct_ac as AgentComponent).agent_id = rec.agent_id
		(direct_ac as AgentComponent).kind = rec.kind

	# Placement: simple logic
	if _should_place_by_spawn_marker(rec):
		var sp := rec.get_last_spawn_point()
		if sp != null and sp.is_valid():
			n2.global_position = sp.position
			rec.needs_spawn_marker = false
		else:
			n2.global_position = rec.last_world_pos
	else:
		n2.global_position = rec.last_world_pos

	lr.get_entities_root().add_child(n2)

	# Apply non-position state
	registry.apply_record_to_node(n2, false)

	# Update record if placed by marker
	if rec.needs_spawn_marker == false:
		registry.upsert_record(rec)
		registry.capture_record_from_node(n2)

	return n2

func _seed_missing_npc_records() -> void:
	var did_seed := false
	for cfg in _npc_configs.values():
		if cfg == null or not cfg.is_valid():
			continue
		if registry.get_record(cfg.npc_id) != null:
			continue

		registry.upsert_record(cfg.create_initial_record())
		did_seed = true

	if did_seed:
		# Persistence is owned by Runtime (and AgentBrain tick) now.
		pass

func _should_place_by_spawn_marker(rec: AgentRecord) -> bool:
	if rec == null:
		return false
	if rec.last_spawn_point_path.is_empty():
		return false
	return bool(rec.needs_spawn_marker)

#endregion
