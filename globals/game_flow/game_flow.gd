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
var _transitioning: bool = false

func _ready() -> void:
	# Must keep running while the SceneTree is paused (so we can unpause).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_ensure_pause_action_registered()
	call_deferred("_boot")

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
	await _run_loading(func() -> bool:
		if GameManager == null:
			return false
		return await GameManager.start_new_game()
	)

func continue_session() -> void:
	await _run_loading(func() -> bool:
		if GameManager == null:
			return false
		return await GameManager.continue_session()
	)

func load_from_slot(slot: String) -> void:
	await _run_loading(func() -> bool:
		if GameManager == null:
			return false
		return await GameManager.load_from_slot(slot)
	)

func return_to_main_menu() -> void:
	_set_state(State.MENU)

func _run_loading(action: Callable) -> void:
	if _transitioning:
		return
	_transitioning = true

	# Always start from a clean unpaused baseline.
	_force_unpaused()
	# Hide overlays that could sit above the loading screen.
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.hide(UIManager.ScreenName.LOAD_GAME_MENU)

	_emit_state_change(State.LOADING)

	# Prevent the "white blink": fade to black while menu is still visible behind it.
	var loading: LoadingScreen = null
	if UIManager != null and UIManager.has_method("show"):
		loading = UIManager.show(UIManager.ScreenName.LOADING_SCREEN) as LoadingScreen
	if loading != null:
		await loading.fade_out()

	# Now that we're black, remove menu screens.
	_hide_all_menus()

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
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.LOADING_SCREEN)

	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast("Loaded." if ok else "Action failed.")

	_transitioning = false

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
	GameManager.autosave_session()
	get_tree().change_scene_to_file("res://main.tscn")
	if UIManager != null and UIManager.has_method("show"):
		UIManager.show(UIManager.ScreenName.MAIN_MENU)

func _enter_in_game() -> void:
	_force_unpaused()
	_hide_all_menus()

func _enter_paused() -> void:
	if state != State.PAUSED:
		return

	# Pause all gameplay.
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
	get_tree().paused = false

	var p := _get_player()
	if p != null and p.has_method("set_input_enabled"):
		p.call("set_input_enabled", true)

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

func _get_player() -> Node:
	var nodes := get_tree().get_nodes_in_group(Groups.PLAYER)
	if nodes.is_empty():
		return null
	return nodes[0] as Node

func _show_pause_menu() -> void:
	if UIManager == null or not UIManager.has_method("show"):
		return
	var menu_v := UIManager.show(UIManager.ScreenName.PAUSE_MENU)
	if menu_v == null or not (menu_v is Control):
		return
	var menu := menu_v as Control

	var resume_cb := Callable(self, "_on_pause_resume_requested")
	var save_cb := Callable(self, "_on_pause_save_requested")
	var load_cb := Callable(self, "_on_pause_load_requested")
	var quit_menu_cb := Callable(self, "_on_pause_quit_to_menu_requested")
	var quit_cb := Callable(self, "_on_pause_quit_requested")

	if menu.has_signal("resume_requested") and not menu.is_connected("resume_requested", resume_cb):
		menu.connect("resume_requested", resume_cb)
	if menu.has_signal("save_requested") and not menu.is_connected("save_requested", save_cb):
		menu.connect("save_requested", save_cb)
	if menu.has_signal("load_requested") and not menu.is_connected("load_requested", load_cb):
		menu.connect("load_requested", load_cb)
	if (menu.has_signal("quit_to_menu_requested")
		and not menu.is_connected("quit_to_menu_requested", quit_menu_cb)):
		menu.connect("quit_to_menu_requested", quit_menu_cb)
	if menu.has_signal("quit_requested") and not menu.is_connected("quit_requested", quit_cb):
		menu.connect("quit_requested", quit_cb)

func _on_pause_resume_requested() -> void:
	_set_state(State.IN_GAME)

func _on_pause_save_requested(slot: String) -> void:
	var ok := false
	if GameManager != null:
		ok = GameManager.save_to_slot(slot)
	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast("Saved." if ok else "Save failed.")

func _on_pause_load_requested(slot: String) -> void:
	# Leave paused state first so we don't get stuck paused after load.
	_set_state(State.IN_GAME)
	await load_from_slot(slot)

func _on_pause_quit_to_menu_requested() -> void:
	_set_state(State.MENU)

func _on_pause_quit_requested() -> void:
	GameManager.autosave_session()
	get_tree().quit()

