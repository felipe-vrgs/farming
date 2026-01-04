class_name DialogueStateSnapshotter
extends Node

## Handles capturing and restoring agent states during cutscenes/dialogue.
## Best-effort "return cutscene agents to their pre-cutscene state".

## StringName agent_id -> AgentRecord snapshot (duplicated).
var _cutscene_agent_snapshots: Dictionary[StringName, AgentRecord] = {}


func clear() -> void:
	_cutscene_agent_snapshots.clear()


func capture_cutscene_agent_snapshots() -> void:
	_cutscene_agent_snapshots.clear()

	# Capture best-effort authoritative records for cutscene agents.
	if AgentBrain != null and AgentBrain.spawner != null:
		AgentBrain.spawner.capture_spawned_agents()

	if AgentBrain == null or AgentBrain.registry == null:
		return

	# Snapshot all currently-spawned agents (best-effort cutscene participants).
	# IMPORTANT:
	# - Snapshots are only applied via explicit restoration events in the cutscene timeline.
	# - We intentionally over-capture (all spawned agents) to avoid hardcoding specific NPC ids.
	# - Player is included separately because spawner only tracks non-player agents.
	var ids: Array[StringName] = []

	var player_id := _find_player_agent_id()
	if not String(player_id).is_empty():
		ids.append(player_id)

	if AgentBrain.spawner != null:
		for agent_id in AgentBrain.spawner.get_spawned_agent_ids():
			var id_sn := StringName(String(agent_id))
			if String(id_sn).is_empty():
				continue
			if not ids.has(id_sn):
				ids.append(id_sn)

	for id in ids:
		var rec_any = AgentBrain.registry.get_record(id)
		if rec_any is AgentRecord:
			_cutscene_agent_snapshots[id] = (rec_any as AgentRecord).duplicate(true)


func restore_cutscene_agent_snapshot(agent_id: StringName) -> void:
	# Explicit restoration hook for cutscene timelines (called by Dialogic events).
	if String(agent_id).is_empty():
		return
	if AgentBrain == null or AgentBrain.registry == null:
		return

	# Map "player" to the actual player record id (some saves use dynamic ids).
	var effective_id := agent_id
	if agent_id == &"player":
		var pid := _find_player_agent_id()
		if String(pid).is_empty():
			return
		effective_id = pid

	var snap: AgentRecord = _cutscene_agent_snapshots.get(effective_id) as AgentRecord
	if snap == null:
		return

	# Restore record (duplicate so we don't keep a live reference).
	AgentBrain.registry.upsert_record(snap.duplicate(true))

	# If restoring the player and the snapshot is in a different level, we must
	# actually change the active level scene; syncing alone won't swap scenes.
	if agent_id == &"player" and Runtime != null:
		var target_level: Enums.Levels = snap.current_level_id
		var active_level: Enums.Levels = Runtime.get_active_level_id()
		if target_level != Enums.Levels.NONE and target_level != active_level:
			# Use an in-memory spawn point so the player lands exactly at the snapshot position.
			var sp := SpawnPointData.new()
			sp.level_id = target_level
			sp.position = snap.last_world_pos
			# Cutscene-safe: do NOT write session saves mid-timeline.
			await Runtime.perform_level_warp(target_level, sp)

	# Sync spawns for the active level so level membership changes are respected.
	if AgentBrain.spawner != null and Runtime != null:
		var lr := Runtime.get_active_level_root()
		if lr != null:
			AgentBrain.spawner.sync_agents_for_active_level(lr)

	# If agent exists in the current scene, apply position immediately.
	if Runtime != null:
		# Prefer resolving by effective id so non-stable player ids work too.
		var query_id := effective_id if agent_id != &"player" else &"player"
		var node := Runtime.find_agent_by_id(query_id)
		if node != null:
			AgentBrain.registry.apply_record_to_node(node, true)

	# Consume snapshot once applied (explicit action semantics).
	_cutscene_agent_snapshots.erase(effective_id)

	if is_inside_tree():
		await get_tree().process_frame


func _find_player_agent_id() -> StringName:
	# Prefer stable id.
	if AgentBrain == null or AgentBrain.registry == null:
		return &""
	var direct = AgentBrain.registry.get_record(&"player")
	if direct is AgentRecord:
		return &"player"
	# Fallback: first record tagged PLAYER.
	for r in AgentBrain.registry.list_records():
		if r != null and r.kind == Enums.AgentKind.PLAYER:
			return r.agent_id
	return &""
