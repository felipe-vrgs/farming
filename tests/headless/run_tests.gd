extends Node

## Minimal headless test runner (no external addons).
## Run with:
##   godot --headless --scene res://tests/headless/test_runner.tscn
##
## Notes:
## - Keep tests deterministic (avoid timers/time-of-day unless you control it).
## - Prefer testing pure logic modules and "offline adapters" over live SceneTree behavior.

var _failures: Array[String] = []
var _passes: int = 0

# name -> Callable
var _tests: Array[Dictionary] = []
var _finished: bool = false

const _EMPTY_SCENE := "res://tests/headless/empty_scene.tscn"

# These are the autoload nodes defined in `project.godot` under `[autoload]`.
# In headless tests we proactively free them before quitting to avoid shutdown
# warnings about leaked instances/RIDs.
const _AUTOLOAD_NODE_NAMES: Array[StringName] = [
	&"TimeManager",
	&"VFXManager",
	&"SFXManager",
	&"Enums",
	&"EventBus",
	&"Debug",
	&"WorldGrid",
	&"UIManager",
	&"AgentBrain",
	&"Runtime",
	&"Dialogic",
	&"DialogueManager",
	&"RelationshipManager",
]


func _ready() -> void:
	# Defer so autoloads exist and the engine is fully initialized.
	call_deferred("_main")


func _main() -> void:
	_start_watchdog()
	await get_tree().process_frame

	_print_header()

	# Clean up any artifacts from previous aborted runs before we start.
	_cleanup_test_artifacts()

	_register_suites()
	for t in _tests:
		await _run_test(String(t["name"]), t["fn"] as Callable)

	_cleanup_test_artifacts()
	_print_summary()
	await _shutdown_for_clean_exit()
	_finished = true
	get_tree().quit(1 if _failures.size() > 0 else 0)


#region tiny assertion helpers
func _fail(msg: String) -> void:
	_failures.append(msg)
	push_error("[TEST] FAIL: " + msg)


func _pass(n: String) -> void:
	_passes += 1
	print("[TEST] PASS: " + n)


func _assert_true(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _assert_eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		_fail("%s (expected=%s got=%s)" % [msg, str(b), str(a)])


func _assert_ne(a: Variant, b: Variant, msg: String) -> void:
	if a == b:
		_fail("%s (did not expect=%s)" % [msg, str(a)])


#endregion


func _run_test(n: String, fn: Callable) -> void:
	var before := _failures.size()
	var t0 := Time.get_ticks_msec()
	await fn.call()
	var dt := Time.get_ticks_msec() - t0
	if _failures.size() == before:
		_pass("%s (%dms)" % [n, dt])
	else:
		print("[TEST] FAIL: %s (%dms)" % [n, dt])


func _print_header() -> void:
	print("========================================")
	print("Headless tests: Farming (Godot)")
	print("Godot version: ", Engine.get_version_info())
	print("========================================")


func _print_summary() -> void:
	print("----------------------------------------")
	print("Passes: ", _passes)
	print("Failures: ", _failures.size())
	if _failures.size() > 0:
		print("Failed tests / assertions:")
		for f in _failures:
			print(" - ", f)
	print("----------------------------------------")


func _start_watchdog() -> void:
	var raw := OS.get_environment("FARMING_TEST_TIMEOUT_S")
	var timeout_s := 60.0
	if raw != null and String(raw).is_valid_float():
		timeout_s = float(raw)
	timeout_s = maxf(5.0, timeout_s)

	# Kill-switch: if something hangs (scene change, await, etc.), exit with a clear message.
	call_deferred("_watchdog", timeout_s)


func _watchdog(timeout_s: float) -> void:
	await get_tree().create_timer(timeout_s).timeout
	if _finished:
		return
	push_error("[TEST] Watchdog timeout after %.1fs (tests likely hung). Forcing quit." % timeout_s)
	_print_summary()
	_cleanup_test_artifacts()
	get_tree().quit(3)


func add_test(n: String, fn: Callable) -> void:
	_tests.append({"name": n, "fn": fn})


func _register_suites() -> void:
	_tests.clear()
	var suite_paths: Array[String] = [
		"res://tests/headless/suites/player_scene_suite.gd",
		"res://tests/headless/suites/environment_suite.gd",
		"res://tests/headless/suites/save_suite.gd",
		"res://tests/headless/suites/relationship_suite.gd",
		"res://tests/headless/suites/agent_registry_suite.gd",
		"res://tests/headless/suites/agent_schedule_suite.gd",
		"res://tests/headless/suites/interaction_toolpress_suite.gd",
		"res://tests/headless/suites/game_flow_suite.gd",
		"res://tests/headless/suites/dialogue_manager_suite.gd",
		"res://tests/headless/suites/runtime_suite.gd",
		"res://tests/headless/suites/sleep_suite.gd"
	]

	for p in suite_paths:
		if not ResourceLoader.exists(p):
			_fail("Missing test suite: %s" % p)
			continue
		var script = load(p)
		if script == null:
			_fail("Failed to load suite script: %s" % p)
			continue
		if not (script is Script):
			_fail("Suite is not a Script: %s" % p)
			continue
		var suite = (script as Script).new()
		if suite == null or not suite.has_method("register"):
			_fail("Invalid suite instance (missing register): %s" % p)
			continue
		suite.register(self)


func _get_autoload(n: StringName) -> Node:
	# Autoloads live under /root/<Name>.
	# We avoid referring to them as identifiers because some autoload scripts do not use `class_name`.
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null(NodePath(String(n))) as Node


# region cleanup
func _cleanup_test_artifacts() -> void:
	# Keep this best-effort; never fail the run because cleanup failed.
	_cleanup_test_sessions("test_session_")
	_cleanup_test_slots("test_")


func _shutdown_for_clean_exit() -> void:
	# 1) If runtime tests swapped scenes, switch to an empty scene to ensure any
	# previous current_scene is fully freed.
	if ResourceLoader.exists(_EMPTY_SCENE):
		get_tree().change_scene_to_file(_EMPTY_SCENE)
		# Allow scene switch + queued frees to flush.
		await get_tree().process_frame
		await get_tree().process_frame

	# 2) Free autoloads so their nodes/resources can be released before engine shutdown.
	var root := get_tree().root
	if root == null:
		return

	for n in _AUTOLOAD_NODE_NAMES:
		var node := root.get_node_or_null(NodePath(String(n)))
		if node != null and node != self:
			node.queue_free()

	# 3) Free any remaining root children except this runner.
	for child in root.get_children():
		if child == self:
			continue
		child.queue_free()

	# 4) Give Godot a couple frames to actually release RIDs/resources.
	await get_tree().process_frame
	await get_tree().process_frame


func _cleanup_test_sessions(prefix: String) -> void:
	var sessions_root := "user://sessions"
	if not DirAccess.dir_exists_absolute(sessions_root):
		return
	var da := DirAccess.open(sessions_root)
	if da == null:
		return

	var removed := 0
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry != "." and entry != ".." and da.current_is_dir() and entry.begins_with(prefix):
			var full := "%s/%s" % [sessions_root, entry]
			_delete_dir_recursive(full)
			removed += 1
		entry = da.get_next()
	da.list_dir_end()

	if removed > 0:
		print("[TEST] Cleanup: removed ", removed, " session dir(s) from ", sessions_root)


func _cleanup_test_slots(prefix: String) -> void:
	# Slots live under user://saves/<slot_name>. Tests may create "test_slot" (and potentially others).
	var saves_root := "user://saves"
	if not DirAccess.dir_exists_absolute(saves_root):
		return
	var da := DirAccess.open(saves_root)
	if da == null:
		return

	var removed := 0
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry != "." and entry != ".." and da.current_is_dir() and entry.begins_with(prefix):
			var full := "%s/%s" % [saves_root, entry]
			_delete_dir_recursive(full)
			removed += 1
		entry = da.get_next()
	da.list_dir_end()

	if removed > 0:
		print("[TEST] Cleanup: removed ", removed, " slot dir(s) from ", saves_root)


func _delete_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = da.get_next()
			continue
		var full := "%s/%s" % [path, entry]
		if da.current_is_dir():
			_delete_dir_recursive(full)
			DirAccess.remove_absolute(full)
		else:
			DirAccess.remove_absolute(full)
		entry = da.get_next()
	da.list_dir_end()
	DirAccess.remove_absolute(path)

# endregion

# Suites live under `tests/headless/suites/` and call `runner.add_test(...)`.
