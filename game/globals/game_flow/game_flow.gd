extends Node

## GameFlow (v1)
## Authoritative game-flow state machine.

signal state_changed(prev: int, next: int)

enum State {
	BOOT = 0,
	MENU = 1,
	LOADING = 2,
	IN_GAME = 3,
	PAUSED = 4,
}

const _PAUSE_REASON_MENU := &"pause_menu"

var state: int = State.BOOT
var active_level_id: Enums.Levels = Enums.Levels.NONE
var _transitioning: bool = false


func _is_test_mode() -> bool:
	# Headless test runner: avoid booting to MENU and changing scenes,
	# otherwise the test runner scene gets replaced and the process never quits.
	return OS.get_environment("FARMING_TEST_MODE") == "1"


func _ready() -> void:
	if _is_test_mode():
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process_unhandled_input(false)
		return

	# Must keep running while the SceneTree is paused (so we can unpause).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_ensure_pause_action_registered()
	if (
		EventBus != null
		and not EventBus.level_change_requested.is_connected(_on_level_change_requested)
	):
		EventBus.level_change_requested.connect(_on_level_change_requested)
	if (
		EventBus != null
		and not EventBus.active_level_changed.is_connected(_on_active_level_changed)
	):
		EventBus.active_level_changed.connect(_on_active_level_changed)
	call_deferred("_boot")


func _on_active_level_changed(_prev: Enums.Levels, next: Enums.Levels) -> void:
	active_level_id = next


func _boot() -> void:
	_set_state(State.BOOT)
	_set_state(State.MENU)


func _ensure_pause_action_registered() -> void:
	# Pause must work before Player exists (menu).
	var action := StringName("pause")
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var desired: Array[Key] = [KEY_ESCAPE, KEY_P]
	for keycode in desired:
		var has := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == keycode:
				has = true
				break
		if has:
			continue
		var e := InputEventKey.new()
		e.physical_keycode = keycode
		InputMap.action_add_event(action, e)


func _unhandled_input(event: InputEvent) -> void:
	if event == null:
		return
	if _transitioning:
		return

	if event.is_action_pressed(&"pause"):
		if state == State.IN_GAME:
			_set_state(State.PAUSED)
		elif state == State.PAUSED:
			_set_state(State.IN_GAME)


func start_new_game() -> void:
	await _run_loading(
		func() -> bool:
			if Runtime == null:
				return false
			return await Runtime.start_new_game()
	)


func continue_session() -> void:
	await _run_loading(
		func() -> bool:
			if Runtime == null:
				return false
			return await Runtime.continue_session()
	)


func load_from_slot(slot: String) -> void:
	await _run_loading(
		func() -> bool:
			if Runtime == null:
				return false
			return await Runtime.load_from_slot(slot)
	)


## Public hook: allow non-GameFlow systems (e.g. cutscenes) to reuse the loading pipeline
## without duplicating fade/menu logic.
func run_loading_action(action: Callable) -> bool:
	return await _run_loading(action)


func _on_level_change_requested(
	target_level_id: Enums.Levels, fallback_spawn_point: SpawnPointData
) -> void:
	# Gameplay travel: run through the same loading pipeline as menu actions.
	await _run_loading(
		func() -> bool:
			if Runtime == null or not Runtime.has_method("perform_level_change"):
				return false
			return await Runtime.perform_level_change(target_level_id, fallback_spawn_point)
	)


func return_to_main_menu() -> void:
	_set_state(State.MENU)


#region UI actions (called by UI scripts)


func resume_game() -> void:
	_set_state(State.IN_GAME)


func save_game_to_slot(slot: String = "default") -> void:
	var ok := false
	if Runtime != null:
		ok = Runtime.save_to_slot(slot)
	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast("Saved." if ok else "Save failed.")


func load_game_from_slot(slot: String = "default") -> void:
	# Ensure we are not stuck paused after load.
	_set_state(State.IN_GAME)
	await load_from_slot(slot)


func quit_to_menu() -> void:
	_set_state(State.MENU)


func quit_game() -> void:
	if Runtime != null:
		Runtime.autosave_session()
	get_tree().quit()


#endregion


func _run_loading(action: Callable) -> bool:
	if _transitioning:
		return false
	_transitioning = true

	# Always start from a clean unpaused baseline.
	_force_unpaused()
	# Hide overlays that could sit above the loading screen.
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.hide(UIManager.ScreenName.LOAD_GAME_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)

	_emit_state_change(State.LOADING)

	# Prevent the "white blink": fade to black while menu is still visible behind it.
	var loading: LoadingScreen = null
	if UIManager != null:
		loading = UIManager.acquire_loading_screen()
	if loading != null:
		await loading.fade_out()

	# Now that we're black, remove menu screens.
	_hide_all_menus()

	if DialogueManager != null:
		DialogueManager.stop_dialogue()

	var ok := false
	if action != null:
		ok = bool(await action.call())

	# If a load succeeded, we should now be in a level scene.
	if ok:
		_set_state(State.IN_GAME)
	else:
		_set_state(State.MENU)

	if loading != null:
		await loading.fade_in()
	if UIManager != null:
		UIManager.release_loading_screen()

	_transitioning = false
	return ok


func _set_state(next: int) -> void:
	if _transitioning and next != State.PAUSED and next != State.IN_GAME:
		# Allow pause toggles only when not transitioning.
		return

	if state == next:
		return

	var was_transitioning := _transitioning
	_transitioning = true
	_force_unpaused()

	match state:
		State.PAUSED:
			_exit_paused()

	_emit_state_change(next)

	match next:
		State.BOOT:
			pass
		State.MENU:
			_enter_menu()
		State.IN_GAME:
			_enter_in_game()
		State.PAUSED:
			_enter_paused()
		State.LOADING:
			# LOADING is entered via _run_loading()
			pass

	_transitioning = was_transitioning


func _emit_state_change(next: int) -> void:
	var prev := state
	state = next
	state_changed.emit(prev, next)


func _enter_menu() -> void:
	_force_unpaused()
	_hide_all_menus()

	if Runtime != null:
		Runtime.autosave_session()
	if DialogueManager != null:
		DialogueManager.stop_dialogue()
	if EventBus != null and active_level_id != Enums.Levels.NONE:
		EventBus.active_level_changed.emit(active_level_id, Enums.Levels.NONE)
	get_tree().change_scene_to_file("res://main.tscn")
	if UIManager != null and UIManager.has_method("show"):
		UIManager.show(UIManager.ScreenName.MAIN_MENU)


func _enter_in_game() -> void:
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_MENU)

	var should_unpause_tree := true
	var show_hud := true

	if Runtime != null and "flow_state" in Runtime:
		match Runtime.flow_state:
			Enums.FlowState.DIALOGUE:
				should_unpause_tree = false
				show_hud = false
			Enums.FlowState.CUTSCENE:
				should_unpause_tree = true
				show_hud = false
			Enums.FlowState.RUNNING:
				should_unpause_tree = true
				show_hud = true

	get_tree().paused = not should_unpause_tree

	_hide_all_menus()
	if show_hud and UIManager != null:
		UIManager.show(UIManager.ScreenName.HUD)


func _enter_paused() -> void:
	if state != State.PAUSED:
		return

	# Pause all gameplay.
	if UIManager != null:
		UIManager.show(UIManager.ScreenName.HUD)
	get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(_PAUSE_REASON_MENU)

	var p := _get_player()
	if p != null and p.has_method("set_input_enabled"):
		p.call("set_input_enabled", false)

	_show_pause_menu()


func _exit_paused() -> void:
	# Resume gameplay.
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)

	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_MENU)

	# Determine if we should unpause the tree and enable input based on Runtime flow state.
	var should_unpause_tree := true
	var should_enable_input := true

	if Runtime != null:
		match Runtime.flow_state:
			Enums.FlowState.DIALOGUE:
				should_unpause_tree = false
				should_enable_input = false
			Enums.FlowState.CUTSCENE:
				should_unpause_tree = true
				should_enable_input = false
			Enums.FlowState.RUNNING:
				should_unpause_tree = true
				should_enable_input = true

	get_tree().paused = not should_unpause_tree

	var p := _get_player()
	if p != null and p.has_method("set_input_enabled"):
		p.call("set_input_enabled", should_enable_input)


func _force_unpaused() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_MENU)


func _hide_all_menus() -> void:
	if UIManager == null or not UIManager.has_method("hide"):
		return
	UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
	UIManager.hide(UIManager.ScreenName.LOAD_GAME_MENU)
	UIManager.hide(UIManager.ScreenName.MAIN_MENU)
	UIManager.hide(UIManager.ScreenName.HUD)


func _get_player() -> Node:
	var nodes := get_tree().get_nodes_in_group(Groups.PLAYER)
	if nodes.is_empty():
		return null
	return nodes[0] as Node


func _show_pause_menu() -> void:
	if UIManager == null or not UIManager.has_method("show"):
		return
	UIManager.show(UIManager.ScreenName.PAUSE_MENU)
