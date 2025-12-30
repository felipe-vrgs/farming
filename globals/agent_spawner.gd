extends Node

## AgentSpawner (v1):
## - Centralizes the logic of turning persisted `AgentRegistry` records into runtime agent nodes
##   when a level is active.
## - Player remains special-cased for placement policy (record vs spawn marker).
## - Non-player agents (e.g. NPCs) are spawned/despawned based on:
##   rec.kind != PLAYER and rec.current_level_id == active_level_id.

const _PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const _NPC_SCRIPT := preload("res://entities/npc/npc.gd")


## StringName agent_id -> Node (non-player agents only)
var _spawned_agents: Dictionary[StringName, Node] = {}

func sync_all(
	p: Enums.PlayerPlacementPolicy = Enums.PlayerPlacementPolicy.RECORD_OR_SPAWN,
	spawn_id: Enums.SpawnId = Enums.SpawnId.PLAYER_DEFAULT
) -> void:
	sync_player_on_level_loaded(p, spawn_id)
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
	(lr.get_entities_root() as Node).add_child(p)
	p.global_position = pos
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

func seed_player_for_new_game(spawn_id: Enums.SpawnId = Enums.SpawnId.PLAYER_DEFAULT) -> Player:
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

func sync_player_on_level_loaded(
	placement_policy: Enums.PlayerPlacementPolicy = Enums.PlayerPlacementPolicy.RECORD_OR_SPAWN,
	spawn_id: Enums.SpawnId = Enums.SpawnId.PLAYER_DEFAULT
) -> Player:
	# Called after:
	# - the level scene is active
	# - (optional) LevelSave hydration is complete
	# This ensures the runtime player exists and is consistent with the `AgentRegistry` record.
	var lr := GameManager.get_active_level_root() if GameManager != null else null
	if lr == null:
		return null

	# Prevent runtime movement events from overwriting loaded agent records while we spawn/apply.
	if AgentRegistry != null:
		AgentRegistry.set_runtime_capture_enabled(false)
		AgentRegistry.load_from_session()

	var rec: AgentRecord = null
	if AgentRegistry != null:
		rec = AgentRegistry.get_record(&"player") as AgentRecord

	var p := _get_player_node()

	# 1) Placement (spawn/move).
	match placement_policy:
		Enums.PlayerPlacementPolicy.SPAWN_MARKER:
			p = _spawn_or_move_player_to_spawn(lr, spawn_id)
		Enums.PlayerPlacementPolicy.RECORD:
			if rec != null:
				p = _spawn_player_at_pos(lr, rec.last_world_pos)
			else:
				p = _spawn_or_move_player_to_spawn(lr, spawn_id)
		_:
			# RECORD_OR_SPAWN
			if rec != null:
				p = _spawn_player_at_pos(lr, rec.last_world_pos)
			else:
				p = _spawn_or_move_player_to_spawn(lr, spawn_id)

	if p == null:
		if AgentRegistry != null:
			AgentRegistry.set_runtime_capture_enabled(true)
		return null

	# 2) Apply record state (inventory/tool selection). Position was handled by placement.
	if AgentRegistry != null and rec != null:
		AgentRegistry.apply_record_to_node(p, false)
	elif AgentRegistry != null and rec == null:
		# First time: seed a record from the spawned player.
		AgentRegistry.capture_record_from_node(p)
		AgentRegistry.save_to_session()

	# 3) If we placed via spawn marker, we want the record to immediately reflect the new location.
	if AgentRegistry != null and placement_policy == Enums.PlayerPlacementPolicy.SPAWN_MARKER:
		AgentRegistry.capture_record_from_node(p)
		AgentRegistry.save_to_session()

	if AgentRegistry != null:
		AgentRegistry.set_runtime_capture_enabled(true)
	return p

func capture_spawned_agents() -> void:
	# Capture non-player agent state back into AgentRegistry (does not save to disk).
	if AgentRegistry == null:
		return
	for agent_id in _spawned_agents.keys():
		var node: Node = _spawned_agents.get(agent_id) as Node
		if node == null or not is_instance_valid(node):
			continue
		AgentRegistry.capture_record_from_node(node)

func sync_agents_for_active_level() -> void:
	# Spawn/despawn non-player agents based on AgentRegistry records for the active level.
	if AgentRegistry == null or GameManager == null:
		return
	var lr := GameManager.get_active_level_root()
	if lr == null:
		return
	var active_level_id: Enums.Levels = lr.level_id

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

	# Despawn agents that no longer belong in the active level.
	for agent_id in _spawned_agents.keys():
		if desired.has(agent_id):
			continue
		var node: Node = _spawned_agents.get(agent_id) as Node
		if node != null and is_instance_valid(node):
			AgentRegistry.capture_record_from_node(node)
			node.queue_free()
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
			if _NPC_SCRIPT != null:
				node = (_NPC_SCRIPT as Script).new()
		_:
			# Unknown kind: ignore for now.
			return null

	if not (node is Node2D):
		if node != null:
			node.queue_free()
		return null

	var n2 := node as Node2D
	(lr.get_entities_root() as Node).add_child(n2)

	# Ensure the runtime node has the correct identity before applying.
	var ac := ComponentFinder.find_component_in_group(n2, Groups.AGENT_COMPONENTS)
	if ac is AgentComponent:
		(ac as AgentComponent).agent_id = rec.agent_id
		(ac as AgentComponent).kind = rec.kind

	# Placement: prefer explicit spawn markers if present; otherwise use recorded position.
	var placed_by_marker := false
	if rec.last_spawn_id != Enums.SpawnId.NONE and SpawnManager != null:
		placed_by_marker = SpawnManager.move_actor_to_spawn(n2, lr, rec.last_spawn_id)
	if not placed_by_marker:
		n2.global_position = rec.last_world_pos

	# Apply non-position state. (Position was handled above.)
	if AgentRegistry != null:
		AgentRegistry.apply_record_to_node(n2, false)

	# If we placed via marker, keep the record consistent immediately.
	if AgentRegistry != null and placed_by_marker:
		AgentRegistry.capture_record_from_node(n2)

	return n2


