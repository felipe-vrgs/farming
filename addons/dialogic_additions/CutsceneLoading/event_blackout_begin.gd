@tool
extends DialogicEvent

## Begin a blackout transaction (fade to black and keep it black).
## Nested calls are supported; only the first call performs the fade-out.
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
	if UIManager == null or not UIManager.has_method("acquire_loading_screen"):
		push_warning("BlackoutBegin: UIManager loading screen not available.")
		finish()
		return

	var depth := _get_depth()
	_set_depth(depth + 1)

	# Only the first begin acquires + fades out. Nested begins just bump the depth.
	if depth != 0:
		finish()
		return

	var loading: LoadingScreen = UIManager.acquire_loading_screen()
	if loading == null:
		# Roll back depth so we don't get stuck "in blackout".
		_set_depth(0)
		push_warning("BlackoutBegin: failed to acquire loading screen.")
		finish()
		return

	dialogic.current_state = dialogic.States.WAITING
	await loading.fade_out(maxf(0.0, time))
	dialogic.current_state = dialogic.States.IDLE

	finish()

func _init() -> void:
	event_name = "Blackout Begin"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 10

func get_shortcode() -> String:
	return "cutscene_blackout_begin"

func get_shortcode_parameters() -> Dictionary:
	return {
		"time": {"property": "time", "default": 0.25},
	}

func build_event_editor() -> void:
	add_header_label("Blackout begin")
	add_header_edit("time", ValueType.NUMBER, {"left_text":"Fade out (s):", "min":0.0})
