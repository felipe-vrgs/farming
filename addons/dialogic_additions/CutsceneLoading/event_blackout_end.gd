@tool
extends DialogicEvent

## End a blackout transaction (fade back in and release the overlay).
## Nested calls are supported; only the last call performs the fade-in.
const _BLACKOUT_DEPTH_KEY := &"dialogic_additions_blackout_depth"

var time: float = 0.25

func _get_depth() -> int:
	var loop := Engine.get_main_loop()
	if loop == null:
		return 0
	return int(loop.get_meta(_BLACKOUT_DEPTH_KEY)) if loop.has_meta(_BLACKOUT_DEPTH_KEY) else 0

func _set_depth(v: int) -> void:
	var loop := Engine.get_main_loop()
	if loop == null:
		return
	loop.set_meta(_BLACKOUT_DEPTH_KEY, v)

func _execute() -> void:
	if dialogic == null:
		finish()
		return
	if UIManager == null or not UIManager.has_method("release_loading_screen"):
		push_warning("BlackoutEnd: UIManager loading screen not available.")
		finish()
		return

	var depth := _get_depth()
	depth = max(0, depth - 1)
	_set_depth(depth)

	# Only the last end fades in + releases. Nested ends just lower the depth.
	if depth != 0:
		finish()
		return

	# We need the loading node to fade in. It should still exist while depth>0
	# (because acquire was called). If it doesn't, just release safely.
	var loading: LoadingScreen = null
	if UIManager.has_method("get_screen_node"):
		loading = UIManager.get_screen_node(UIManager.ScreenName.LOADING_SCREEN) as LoadingScreen

	if loading != null:
		dialogic.current_state = dialogic.States.WAITING
		await loading.fade_in(maxf(0.0, time))
		dialogic.current_state = dialogic.States.IDLE

	UIManager.release_loading_screen()
	finish()

func _init() -> void:
	event_name = "Blackout End"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 11

func get_shortcode() -> String:
	return "cutscene_blackout_end"

func get_shortcode_parameters() -> Dictionary:
	return {
		"time": {"property": "time", "default": 0.25},
	}

func build_event_editor() -> void:
	add_header_label("Blackout end")
	add_header_edit("time", ValueType.NUMBER, {"left_text":"Fade in (s):", "min":0.0})
