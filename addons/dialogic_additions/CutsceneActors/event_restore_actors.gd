@tool
extends DialogicEvent

## Restore one or more actors to their pre-cutscene snapshot captured by DialogueManager.
## This is an explicit action; if the timeline doesn't call it, no auto-restore happens.
##
## Actor ids are provided as a comma-separated string (e.g. "player,frieren").
const _BLACKOUT_DEPTH_KEY := &"dialogic_additions_blackout_depth"

var actor_ids: String = "player"
var auto_blackout: bool = false
var blackout_time: float = 0.25

func _get_blackout_depth() -> int:
	var loop := Engine.get_main_loop()
	if loop == null:
		return 0
	return int(loop.get_meta(_BLACKOUT_DEPTH_KEY)) if loop.has_meta(_BLACKOUT_DEPTH_KEY) else 0

func _set_blackout_depth(v: int) -> void:
	var loop := Engine.get_main_loop()
	if loop == null:
		return
	loop.set_meta(_BLACKOUT_DEPTH_KEY, v)

func _blackout_begin() -> void:
	if UIManager == null or not UIManager.has_method("acquire_loading_screen"):
		return
	var depth := _get_blackout_depth()
	_set_blackout_depth(depth + 1)
	if depth != 0:
		return
	var loading: LoadingScreen = UIManager.acquire_loading_screen()
	if loading != null:
		await loading.fade_out(maxf(0.0, blackout_time))

func _blackout_end() -> void:
	if UIManager == null or not UIManager.has_method("release_loading_screen"):
		return
	var depth := max(0, _get_blackout_depth() - 1)
	_set_blackout_depth(depth)
	if depth != 0:
		return
	var loading: LoadingScreen = null
	if UIManager.has_method("get_screen_node"):
		loading = UIManager.get_screen_node(UIManager.ScreenName.LOADING_SCREEN) as LoadingScreen
	if loading != null:
		await loading.fade_in(maxf(0.0, blackout_time))
	UIManager.release_loading_screen()

func _execute() -> void:
	if DialogueManager == null or not DialogueManager.has_method("restore_cutscene_actor_snapshot"):
		push_warning("RestoreActors: DialogueManager restore API not available.")
		finish()
		return

	if actor_ids.strip_edges().is_empty():
		push_warning("RestoreActors: actor_ids is empty.")
		finish()
		return

	dialogic.current_state = dialogic.States.WAITING
	if auto_blackout:
		await _blackout_begin()

	for raw in actor_ids.split(",", false):
		var t := raw.strip_edges()
		if t.is_empty():
			continue
		await DialogueManager.restore_cutscene_actor_snapshot(StringName(t))

	if auto_blackout:
		await _blackout_end()

	dialogic.current_state = dialogic.States.IDLE
	finish()

func _init() -> void:
	event_name = "Restore Actors"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 5

func get_shortcode() -> String:
	# Keep shortcode stable for existing timelines.
	return "cutscene_restore_actors"

func get_shortcode_parameters() -> Dictionary:
	return {
		"actor_id": {"property": "actor_ids", "default": "player"},
		"auto_blackout": {"property": "auto_blackout", "default": false},
		"blackout_time": {"property": "blackout_time", "default": 0.25},
	}

func build_event_editor() -> void:
	add_header_label("Restore actors")
	add_header_edit(
		"actor_ids",
		ValueType.SINGLELINE_TEXT,
		{"placeholder":"Comma-separated ids (player,frieren,...)"}
	)
	add_body_edit("auto_blackout", ValueType.BOOL, {"left_text":"Auto blackout:"})
	add_body_edit("blackout_time",
		ValueType.NUMBER,
		{"left_text":"Blackout time (s):", "min":0.0},
		"auto_blackout"
	)

