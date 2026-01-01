extends Node

## AgentSpawner (v1):
## - Centralizes the logic of turning persisted `AgentRegistry` records into runtime agent nodes
##   when a level is active.
## - Player remains special-cased for placement policy (record vs spawn marker).
## - Non-player agents (e.g. NPCs) are spawned/despawned based on:
##   rec.kind != PLAYER and rec.current_level_id == active_level_id.

const _PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const _NPC_SCENE: PackedScene = preload("res://entities/npc/npc.tscn")

const _NPC_CONFIGS_DIR := "res://entities/npc/configs"
const _NPC_CONFIG_SCRIPT: Script = preload("res://entities/npc/models/npc_config.gd")

## StringName npc_id -> NpcConfig
var _npc_configs: Dictionary[StringName, NpcConfig] = {}


## StringName agent_id -> Node (non-player agents only)
var _spawned_agents: Dictionary[StringName, Node] = {}

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

func _get_npc_config(npc_id: StringName) -> NpcConfig:
	return _npc_configs.get(npc_id) as NpcConfig

## Public: lookup config for an NPC id.
## Used by offline simulation and debug tooling.
func get_npc_config(npc_id: StringName) -> NpcConfig:
	return _get_npc_config(npc_id)

## Public: ids of currently spawned (non-player) agents in the active level.
func get_spawned_agent_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for agent_id in _spawned_agents.keys():
		out.append(agent_id)
	return out

func _seed_missing_npc_records() -> void:
	# Creates AgentRecords for any configured NPCs that are missing from the session save.
	# This solves "first spawn" for NPCs without requiring per-NPC hardcoded positions.
	if AgentRegistry == null:
		return

	var did_seed := false
	for cfg in _npc_configs.values():
		if cfg == null or not cfg.is_valid():
			continue
		if AgentRegistry.get_record(cfg.npc_id) != null:
			continue

		AgentRegistry.upsert_record(cfg.create_initial_record())
		did_seed = true

	if did_seed:
		AgentRegistry.save_to_session()

func _should_place_agent_by_spawn_marker(rec: AgentRecord) -> bool:
	# We use spawn markers as an *entry intent* (first spawn / travel),
	# not as a perpetual "always place here" override.
	if rec == null:
		return false
	if rec.last_spawn_id == Enums.SpawnId.NONE:
		return false
	return bool(rec.needs_spawn_marker)

## Sync all agents (player + NPCs) for the active level.
## Player placement uses `needs_spawn_marker` flag (set by commit_travel_by_id).
## Fallback spawn_id is used for new game (no record exists yet).
func sync_all(fallback_spawn_id: Enums.SpawnId = Enums.SpawnId.PLAYER_SPAWN) -> void:
	sync_player_on_level_loaded(fallback_spawn_id)
	sync_agents_for_active_level()

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
	(lr.get_entities_root() as Node).add_child(p)
	return p

func _spawn_or_move_player_to_spawn(lr: LevelRoot, spawn_id: Enums.SpawnId) -> Player:
	if lr == null:
		return null
	var existing := _get_player_node()
	if existing != null:
		if SpawnManager != null:
			SpawnManager.move_actor_to_spawn(existing, lr, spawn_id)
		return existing

	if SpawnManager == null:
		return _spawn_player_at_pos(lr, Vector2.ZERO)

	var n := SpawnManager.spawn_actor(_PLAYER_SCENE, lr, spawn_id)
	return n as Player

func seed_player_for_new_game(spawn_id: Enums.SpawnId = Enums.SpawnId.PLAYER_SPAWN) -> Player:
	# New game: player always spawns at a marker, then we seed AgentsSave with the initial record.
	var lr := GameManager.get_active_level_root() if GameManager != null else null
	if lr == null:
		return null

	if AgentRegistry != null:
		AgentRegistry.set_runtime_capture_enabled(false)

	var p := _spawn_or_move_player_to_spawn(lr, spawn_id)
	if p == null:
		if AgentRegistry != null:
			AgentRegistry.set_runtime_capture_enabled(true)
		return null

	if AgentRegistry != null:
		AgentRegistry.capture_record_from_node(p)
		AgentRegistry.save_to_session()
		AgentRegistry.set_runtime_capture_enabled(true)
	return p

## Sync player for active level. Uses same placement logic as NPCs:
## - If needs_spawn_marker = true → place at last_spawn_id marker, then clear flag
## - Else if record exists → place at record position
## - Else → place at fallback_spawn_id (new game scenario)
func sync_player_on_level_loaded(
	fallback_spawn_id: Enums.SpawnId = Enums.SpawnId.PLAYER_SPAWN
) -> Player:
	var lr := GameManager.get_active_level_root() if GameManager != null else null
	if lr == null:
		return null

	AgentRegistry.set_runtime_capture_enabled(false)

	var rec: AgentRecord = AgentRegistry.get_record(&"player") as AgentRecord
	var p := _get_player_node()
	var placed_by_marker := false

	# Placement: same logic as _spawn_agent_for_record() for NPCs.
	if rec != null and _should_place_agent_by_spawn_marker(rec):
		# Travel scenario: commit_travel_by_id() set needs_spawn_marker = true.
		var m := SpawnManager.find_spawn_marker(lr, rec.last_spawn_id) if SpawnManager != null else null
		if m != null:
			p = _spawn_player_at_pos(lr, (m as Marker2D).global_position)
			placed_by_marker = true
			rec.needs_spawn_marker = false
		else:
			# Marker not found, fall back to record position.
			p = _spawn_player_at_pos(lr, rec.last_world_pos)
	elif rec != null:
		# Continue scenario: place at record position.
		p = _spawn_player_at_pos(lr, rec.last_world_pos)
	else:
		# New game scenario: no record yet, use fallback marker.
		p = _spawn_or_move_player_to_spawn(lr, fallback_spawn_id)
		placed_by_marker = true

	if p == null:
		AgentRegistry.set_runtime_capture_enabled(true)
		return null

	# Apply non-position state (inventory/tool selection).
	if rec != null:
		AgentRegistry.apply_record_to_node(p, false)

	# Capture record to persist new position (and create record if new game).
	if placed_by_marker or rec == null:
		AgentRegistry.capture_record_from_node(p)
		if rec != null:
			AgentRegistry.upsert_record(rec)  # Persist needs_spawn_marker = false
		AgentRegistry.save_to_session()

	AgentRegistry.set_runtime_capture_enabled(true)
	return p

func capture_spawned_agents() -> void:
	# Capture non-player agent state back into AgentRegistry (does not save to disk).
	if AgentRegistry == null:
		return
	for agent_id in _spawned_agents.keys():
		var node = _spawned_agents.get(agent_id)
		if node == null or not is_instance_valid(node) or not (node is Node):
			continue
		AgentRegistry.capture_record_from_node(node as Node)

func sync_agents_for_active_level() -> void:
	# Spawn/despawn non-player agents based on AgentRegistry records for the active level.
	if AgentRegistry == null or GameManager == null:
		return
	var lr := GameManager.get_active_level_root()
	if lr == null:
		return
	var active_level_id: Enums.Levels = lr.level_id

	_seed_missing_npc_records()

	# Prevent runtime movement events from overwriting records while we apply state.
	AgentRegistry.set_runtime_capture_enabled(false)

	# Compute desired agent set for this level.
	var desired: Dictionary[StringName, AgentRecord] = {}
	for rec in AgentRegistry.list_records():
		if rec == null:
			continue
		if rec.kind == Enums.AgentKind.PLAYER:
			continue
		if rec.current_level_id != active_level_id:
			continue
		desired[rec.agent_id] = rec

	# Prune stale entries (e.g. level was unloaded and nodes were freed).
	for agent_id in _spawned_agents.keys():
		var node = _spawned_agents.get(agent_id)
		if node == null or not is_instance_valid(node):
			_spawned_agents.erase(agent_id)

	# Despawn agents that no longer belong in the active level.
	for agent_id in _spawned_agents.keys():
		if desired.has(agent_id):
			continue
		var node = _spawned_agents.get(agent_id)
		if node != null and is_instance_valid(node) and (node is Node):
			AgentRegistry.capture_record_from_node(node as Node)
			(node as Node).queue_free()
		_spawned_agents.erase(agent_id)

	# Spawn missing agents and apply state.
	for agent_id in desired.keys():
		if _spawned_agents.has(agent_id):
			continue
		var rec: AgentRecord = desired[agent_id]
		var node := _spawn_agent_for_record(rec, lr)
		if node != null:
			_spawned_agents[agent_id] = node

	AgentRegistry.set_runtime_capture_enabled(true)

func _spawn_agent_for_record(rec: AgentRecord, lr: LevelRoot) -> Node2D:
	if rec == null or lr == null:
		return null

	var node: Node = null
	match rec.kind:
		Enums.AgentKind.NPC:
			if _NPC_SCENE != null:
				node = _NPC_SCENE.instantiate()
		_:
			return null

	if not (node is Node2D):
		if node != null:
			node.queue_free()
		return null

	var n2 := node as Node2D

	# Configure before entering the tree so `_ready` sees final values.
	var npc_cfg := _get_npc_config(rec.agent_id)
	if npc_cfg != null and n2 is NPC:
		(n2 as NPC).set_npc_config(npc_cfg)

	# Ensure the runtime node has the correct identity as early as possible.
	# (Setting the component directly avoids relying on group registration order.)
	var direct_ac := n2.get_node_or_null(NodePath("Components/AgentComponent"))
	if direct_ac is AgentComponent:
		(direct_ac as AgentComponent).agent_id = rec.agent_id
		(direct_ac as AgentComponent).kind = rec.kind

	# Placement: place BEFORE entering the tree so schedule/state init doesn't run at (0,0).
	var placed_by_marker := false
	if _should_place_agent_by_spawn_marker(rec) and SpawnManager != null:
		var m := SpawnManager.find_spawn_marker(lr, rec.last_spawn_id)
		if m != null:
			# Spawn markers are authored as origin world positions.
			n2.global_position = (m as Marker2D).global_position
			placed_by_marker = true
			# Clear the one-shot marker intent now that we've applied it.
			rec.needs_spawn_marker = false
	if not placed_by_marker:
		# `AgentRecord.last_world_pos` is defined as the agent origin (`global_position`).
		n2.global_position = rec.last_world_pos

	(lr.get_entities_root() as Node).add_child(n2)

	# Ensure the runtime node has the correct identity before applying.
	var ac := ComponentFinder.find_component_in_group(n2, Groups.AGENT_COMPONENTS)
	if ac is AgentComponent:
		(ac as AgentComponent).agent_id = rec.agent_id
		(ac as AgentComponent).kind = rec.kind

	# Apply non-position state. (Position was handled above.)
	AgentRegistry.apply_record_to_node(n2, false)

	# If we placed via marker, keep the record consistent immediately.
	if placed_by_marker:
		AgentRegistry.upsert_record(rec)
		AgentRegistry.capture_record_from_node(n2)
		AgentRegistry.save_to_session()

	return n2
