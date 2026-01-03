@tool
extends DialogicEvent

## Change level to a SpawnPointData destination and continue timeline at a label.
## Intended for CUTSCENE mode (SceneTree running; controllers disabled).

var spawn_point_path: String = ""
var resume_label: String = ""

func _execute() -> void:
	if Runtime == null:
		push_warning("ChangeLevelAndContinue: Runtime not available.")
		finish()
		return
	if not Runtime.has_method("perform_level_change"):
		push_warning("ChangeLevelAndContinue: Runtime missing perform_level_change().")
		finish()
		return
	if spawn_point_path.is_empty():
		push_warning("ChangeLevelAndContinue: spawn_point_path is empty.")
		finish()
		return

	var sp_res := load(spawn_point_path)
	var sp: SpawnPointData = sp_res as SpawnPointData
	if sp == null or not sp.is_valid():
		push_warning("ChangeLevelAndContinue: Invalid SpawnPointData at %s" % spawn_point_path)
		finish()
		return

	dialogic.current_state = dialogic.States.WAITING
	_commit_player_travel_to_spawn(sp)
	# Prefer going through GameFlow's loading pipeline (fade, LOADING state, etc.).
	if Runtime.game_flow != null and Runtime.game_flow.has_method("run_loading_action"):
		await Runtime.game_flow.run_loading_action(Callable(self, "_perform_level_change").bind(sp))
	else:
		# Fallback: run the level change directly (no loading UI).
		await Runtime.perform_level_change(sp.level_id, sp)
	await dialogic.get_tree().process_frame

	if not resume_label.is_empty() and dialogic.has_subsystem("Jump"):
		dialogic.Jump.jump_to_label(resume_label)

	dialogic.current_state = dialogic.States.IDLE
	finish()

func _perform_level_change(sp: SpawnPointData) -> bool:
	if Runtime == null or sp == null:
		return false
	return await Runtime.perform_level_change(sp.level_id, sp)

func _commit_player_travel_to_spawn(sp: SpawnPointData) -> void:
	# Ensure player lands exactly at the spawn point for cutscene-driven level changes.
	if sp == null or not sp.is_valid():
		return
	if AgentBrain == null or AgentBrain.registry == null:
		return
	# Prefer stable player id.
	var player_id: StringName = &"player"
	var rec = AgentBrain.registry.get_record(player_id)
	if not (rec is AgentRecord):
		# Fallback: pick first PLAYER record.
		for r in AgentBrain.registry.list_records():
			if r != null and r.kind == Enums.AgentKind.PLAYER:
				player_id = r.agent_id
				break
	AgentBrain.registry.commit_travel_by_id(player_id, sp)

func _init() -> void:
	event_name = "Change Level And Continue"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 3

func get_shortcode() -> String:
	return "cutscene_change_level_continue"

func get_shortcode_parameters() -> Dictionary:
	return {
		"spawn_point": {"property": "spawn_point_path", "default": ""},
		"resume": {"property": "resume_label", "default": ""},
	}

func build_event_editor() -> void:
	add_header_label("Change level")
	add_body_edit("spawn_point_path", ValueType.FILE, {
		"left_text":"Spawn point:",
		"filters":["*.tres"],
	})
	add_body_edit("resume_label", ValueType.SINGLELINE_TEXT, {"left_text":"Resume label:"})

