@tool
extends DialogicEvent

## Force an agent record to a SpawnPointData destination and (best-effort) ensure
## the runtime node is placed there too. Works for player and NPCs.

const _SPAWN_WAIT_MAX_FRAMES := 30
const _SPAWN_POS_EPS := 1.0

var agent_id: String = ""
var spawn_point_path: String = ""
## Optional final facing direction after spawning.
## Supported values: "left", "right", "front", "back". Empty = keep current facing.
var facing_dir: String = ""

func _execute() -> void:
	if String(agent_id).is_empty():
		push_warning("AgentSpawn: agent_id is empty.")
		finish()
		return
	if spawn_point_path.is_empty():
		push_warning("AgentSpawn: spawn_point_path is empty.")
		finish()
		return
	if AgentBrain == null or AgentBrain.registry == null:
		push_warning("AgentSpawn: AgentBrain/registry not available.")
		finish()
		return

	var sp_res := load(spawn_point_path)
	var sp: SpawnPointData = sp_res as SpawnPointData
	if sp == null or not sp.is_valid():
		push_warning("AgentSpawn: Invalid SpawnPointData at %s" % spawn_point_path)
		finish()
		return

	var facing_override := _resolve_facing_override()

	# Resolve "player" alias to the actual player record id if needed.
	var effective_id := StringName(agent_id)
	if effective_id == &"player":
		for r in AgentBrain.registry.list_records():
			if r != null and r.kind == Enums.AgentKind.PLAYER:
				effective_id = r.agent_id
				break

	# Player: if the spawn point is in another level, perform a level change.
	var is_player := false
	var rec_any = AgentBrain.registry.get_record(effective_id)
	if rec_any is AgentRecord and (rec_any as AgentRecord).kind == Enums.AgentKind.PLAYER:
		is_player = true

	if is_player and Runtime != null:
		AgentBrain.registry.commit_travel_by_id(effective_id, sp)
		if facing_override != Vector2.ZERO:
			var prec := AgentBrain.registry.get_record(effective_id) as AgentRecord
			if prec != null:
				prec.facing_dir = facing_override
				AgentBrain.registry.upsert_record(prec)
		if Runtime.has_method("get_active_level_id") and Runtime.get_active_level_id() != sp.level_id:
			await Runtime.perform_level_warp(sp.level_id, sp)
		# Ensure correct placement even if already in the level.
		var pnode := Runtime.find_agent_by_id(&"player")
		if pnode is Node2D:
			var comp_any := ComponentFinder.find_component_in_group(pnode, Groups.CUTSCENE_ACTOR_COMPONENTS)
			var comp := comp_any as CutsceneActorComponent
			if comp == null:
				push_warning("AgentSpawn: Missing CutsceneActorComponent on player.")
			else:
				comp.teleport_to(sp.position, facing_override)
	else:
		# NPC: commit travel + sync spawned agents (NO persistence during timelines).
		if AgentBrain.has_method("commit_travel_and_sync"):
			AgentBrain.commit_travel_and_sync(effective_id, sp, false)
		else:
			# Fallback: directly upsert record if brain API changed.
			var rec = AgentBrain.registry.get_record(effective_id)
			if rec is AgentRecord:
				(rec as AgentRecord).current_level_id = sp.level_id
				(rec as AgentRecord).last_spawn_point_path = sp.resource_path
				(rec as AgentRecord).last_world_pos = sp.position
				if facing_override != Vector2.ZERO:
					(rec as AgentRecord).facing_dir = facing_override
				AgentBrain.registry.upsert_record(rec)

		# Ensure record facing is updated for the common commit_travel_and_sync path too.
		if facing_override != Vector2.ZERO:
			var nrec := AgentBrain.registry.get_record(effective_id) as AgentRecord
			if nrec != null:
				nrec.facing_dir = facing_override
				AgentBrain.registry.upsert_record(nrec)

	# Best-effort warp runtime node if it is currently spawned.
	if Runtime != null and Runtime.has_method("find_agent_by_id"):
		var agent := Runtime.find_agent_by_id(StringName(agent_id))
		if agent is Node2D:
			var comp_any := ComponentFinder.find_component_in_group(agent, Groups.CUTSCENE_ACTOR_COMPONENTS)
			var comp := comp_any as CutsceneActorComponent
			if comp == null:
				push_warning("AgentSpawn: Missing CutsceneActorComponent on agent: %s" % agent_id)
			else:
				comp.teleport_to(sp.position, facing_override)

	# Wait until the NPC is actually spawned/placed before continuing.
	# This is important when timelines use blackout begin/end around spawns.
	if dialogic != null and Runtime != null and Runtime.has_method("find_agent_by_id"):
		dialogic.current_state = dialogic.States.WAITING
		for _i in range(_SPAWN_WAIT_MAX_FRAMES):
			var node := Runtime.find_agent_by_id(StringName(agent_id))
			if node is Node2D and (node as Node2D).is_inside_tree():
				if (node as Node2D).global_position.distance_to(sp.position) <= _SPAWN_POS_EPS:
					break
			await dialogic.get_tree().process_frame
		dialogic.current_state = dialogic.States.IDLE

	finish()

func _resolve_facing_override() -> Vector2:
	var s := facing_dir.strip_edges().to_lower()
	match s:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"front", "down":
			return Vector2.DOWN
		"back", "up":
			return Vector2.UP
		"", "none", "keep":
			return Vector2.ZERO
		_:
			return Vector2.ZERO

func _init() -> void:
	event_name = "Agent Spawn"
	set_default_color("Color7")
	event_category = "Agent"
	event_sorting_index = 4

func get_shortcode() -> String:
	# Keep existing shortcode for backwards compatibility.
	return "cutscene_npc_travel_spawn"

func get_shortcode_parameters() -> Dictionary:
	return {
		# Preferred key:
		"agent_id": {"property": "agent_id", "default": ""},
		"spawn_point": {"property": "spawn_point_path", "default": ""},
		"facing": {"property": "facing_dir", "default": ""},
	}

func build_event_editor() -> void:
	add_header_label("Agent spawn")
	add_body_edit("agent_id", ValueType.DYNAMIC_OPTIONS, {
		"left_text":"Agent id:",
		"placeholder":"player / npc id",
		"mode": 0,
		"suggestions_func": CutsceneOptions.get_agent_id_suggestions,
	})
	add_body_edit("spawn_point_path", ValueType.FILE, {
		"left_text":"Spawn point:",
		"filters":["*.tres"],
	})

	add_body_edit("facing_dir", ValueType.FIXED_OPTIONS, {
		"left_text":"End facing:",
		"options": CutsceneOptions.facing_fixed_options(),
	})
