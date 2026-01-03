@tool
class_name DialogicCutsceneChangeLevelAndContinueEvent
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
	# This yields while Runtime runs its loading pipeline.
	await Runtime.perform_level_change(sp.level_id, sp)
	await dialogic.get_tree().process_frame

	if not resume_label.is_empty() and dialogic.has_subsystem("Jump"):
		dialogic.Jump.jump_to_label(resume_label)

	dialogic.current_state = dialogic.States.IDLE
	finish()

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

