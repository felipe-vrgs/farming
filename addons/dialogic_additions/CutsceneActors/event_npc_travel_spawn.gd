@tool
extends DialogicEvent

## Force an NPC record to a SpawnPointData destination and (best-effort) ensure
## the runtime node is placed there too.
## Fade is intentionally not handled here anymore; control it via dedicated fade events.

var npc_id: String = ""
var spawn_point_path: String = ""
var fade_sec: float = 0.2
# Kept for backwards compatibility (ignored).

func _execute() -> void:
	if String(npc_id).is_empty():
		push_warning("NpcTravelSpawn: npc_id is empty.")
		finish()
		return
	if spawn_point_path.is_empty():
		push_warning("NpcTravelSpawn: spawn_point_path is empty.")
		finish()
		return
	if AgentBrain == null or AgentBrain.registry == null:
		push_warning("NpcTravelSpawn: AgentBrain/registry not available.")
		finish()
		return

	var sp_res := load(spawn_point_path)
	var sp: SpawnPointData = sp_res as SpawnPointData
	if sp == null or not sp.is_valid():
		push_warning("NpcTravelSpawn: Invalid SpawnPointData at %s" % spawn_point_path)
		finish()
		return

	# NOTE: Fade is intentionally not handled here anymore.

	# Commit NPC travel + sync. This ensures the NPC exists in the right level.
	if AgentBrain.has_method("commit_travel_and_sync"):
		AgentBrain.commit_travel_and_sync(npc_id, sp)
	else:
		# Fallback: directly upsert record if brain API changed.
		var rec = AgentBrain.registry.get_record(npc_id)
		if rec is AgentRecord:
			(rec as AgentRecord).current_level_id = sp.level_id
			(rec as AgentRecord).last_spawn_point_path = sp.resource_path
			(rec as AgentRecord).last_world_pos = sp.position
			AgentBrain.registry.upsert_record(rec)

	# Best-effort warp runtime node if it is currently spawned.
	if Runtime != null and Runtime.has_method("find_actor_by_id"):
		var actor := Runtime.find_actor_by_id(npc_id)
		if actor is Node2D:
			(actor as Node2D).global_position = sp.position

	if dialogic != null:
		await dialogic.get_tree().process_frame

	finish()

func _init() -> void:
	event_name = "NPC Travel To Spawn"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 4

func get_shortcode() -> String:
	return "cutscene_npc_travel_spawn"

func get_shortcode_parameters() -> Dictionary:
	return {
		"npc_id": {"property": "npc_id", "default": ""},
		"spawn_point": {"property": "spawn_point_path", "default": ""},
		"fade": {"property": "fade_sec", "default": 0.2},
	}

func build_event_editor() -> void:
	add_header_label("NPC travel")
	add_body_edit("npc_id", ValueType.SINGLELINE_TEXT, {"left_text":"NPC id:"})
	add_body_edit("spawn_point_path", ValueType.FILE, {
		"left_text":"Spawn point:",
		"filters":["*.tres"],
	})
	add_body_edit("fade_sec", ValueType.NUMBER, {
		"left_text":"Fade (sec): (ignored)",
		"min":0.0,
		"step":0.05,
	})

