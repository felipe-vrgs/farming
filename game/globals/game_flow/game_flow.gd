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
	PLAYER_MENU = 5,
	DIALOGUE = 6,
	CUTSCENE = 7,
}

const _PAUSE_REASON_MENU := &"pause_menu"
const _PAUSE_REASON_PLAYER_MENU := &"player_menu"
const _PAUSE_REASON_DIALOGUE := &"dialogue"
const _PAUSE_REASON_CUTSCENE := &"cutscene"

var state: int = State.BOOT
var active_level_id: Enums.Levels = Enums.Levels.NONE
var _transitioning: bool = false
var _states: Dictionary[int, RefCounted] = {}
var _external_loading_depth: int = 0


func _is_test_mode() -> bool:
	# Headless test runner: avoid booting to MENU and changing scenes,
	# otherwise the test runner scene gets replaced and the process never quits.
	return OS.get_environment("FARMING_TEST_MODE") == "1"


func _ready() -> void:
	_init_states()
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


func _init_states() -> void:
	# State objects live in dedicated files under `game_flow/states/`.
	# They are pure logic objects (RefCounted) that operate on this GameFlow node.
	_states.clear()
	_states[State.BOOT] = load("res://game/globals/game_flow/states/boot_state.gd").new(self)
	_states[State.MENU] = load("res://game/globals/game_flow/states/menu_state.gd").new(self)
	_states[State.LOADING] = load("res://game/globals/game_flow/states/loading_state.gd").new(self)
	_states[State.IN_GAME] = load("res://game/globals/game_flow/states/in_game_state.gd").new(self)
	_states[State.PAUSED] = load("res://game/globals/game_flow/states/paused_state.gd").new(self)
	_states[State.PLAYER_MENU] = (
		load("res://game/globals/game_flow/states/player_menu_state.gd").new(self)
	)
	_states[State.DIALOGUE] = load("res://game/globals/game_flow/states/dialogue_state.gd").new(
		self
	)
	_states[State.CUTSCENE] = load("res://game/globals/game_flow/states/cutscene_state.gd").new(
		self
	)


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


func get_flow_state() -> Enums.FlowState:
	# Compatibility layer: many systems treat this as "world mode" (RUNNING/DIALOGUE/CUTSCENE),
	# orthogonal to menu/pause overlays.
	match state:
		State.DIALOGUE:
			return Enums.FlowState.DIALOGUE
		State.CUTSCENE:
			return Enums.FlowState.CUTSCENE
		_:
			return Enums.FlowState.RUNNING


func request_flow_state(next: Enums.FlowState) -> void:
	# Public compatibility method (replaces FlowStateManager.request_flow_state).
	if next == Enums.FlowState.DIALOGUE:
		_set_state(State.DIALOGUE)
		return
	if next == Enums.FlowState.CUTSCENE:
		_set_state(State.CUTSCENE)
		return
	# RUNNING: return to gameplay if we were in dialogue/cutscene.
	if state == State.DIALOGUE or state == State.CUTSCENE:
		_set_state(State.IN_GAME)


func _unhandled_input(event: InputEvent) -> void:
	if event == null:
		return
	if _transitioning:
		return

	var st: RefCounted = _states.get(state)
	if st != null and st.has_method("handle_unhandled_input"):
		# States return true if they consumed the event.
		if bool(st.call("handle_unhandled_input", event)):
			return


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
func run_loading_action(action: Callable, preserve_dialogue_state: bool = false) -> bool:
	return await _run_loading(action, preserve_dialogue_state)


func _on_level_change_requested(
	target_level_id: Enums.Levels, fallback_spawn_point: SpawnPointData
) -> void:
	# Gameplay travel: run through the same loading pipeline as menu actions.
	var cb = func() -> bool:
		if Runtime == null or not Runtime.has_method("perform_level_change"):
			return false
		return await Runtime.perform_level_change(target_level_id, fallback_spawn_point)
	await _run_loading(cb, true)


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


func _run_loading(action: Callable, preserve_dialogue_state: bool = false) -> bool:
	if _transitioning:
		return false
	_transitioning = true

	# Always start from a clean unpaused baseline.
	_force_unpaused()
	# Hide overlays that could sit above the loading screen.
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.hide(UIManager.ScreenName.LOAD_GAME_MENU)
		UIManager.hide(UIManager.ScreenName.PLAYER_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)

	_set_state(State.LOADING)

	# Prevent the "white blink": fade to black while menu is still visible behind it.
	var loading: LoadingScreen = null
	if UIManager != null:
		loading = UIManager.acquire_loading_screen()
	if loading != null:
		await loading.fade_out()

	# Now that we're black, remove menu screens.
	_hide_all_menus()

	if DialogueManager != null:
		DialogueManager.stop_dialogue(preserve_dialogue_state)

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
	if (
		_transitioning
		and next != State.PAUSED
		and next != State.IN_GAME
		and next != State.LOADING
		and next != State.MENU
	):
		# Allow essential flow transitions (LOADING/MENU/IN_GAME) and pause toggles even
		# while the async loading pipeline is active.
		return

	if state == next:
		return

	var was_transitioning := _transitioning
	_transitioning = true
	_force_unpaused()

	var prev := state
	var prev_state: RefCounted = _states.get(prev)
	if prev_state != null and prev_state.has_method("exit"):
		prev_state.call("exit", next)

	_emit_state_change(next)

	var next_state: RefCounted = _states.get(next)
	if next_state != null and next_state.has_method("enter"):
		next_state.call("enter", prev)

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
	# RUNNING gameplay state (single-state machine).
	get_tree().paused = false
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_MENU)
		TimeManager.resume(_PAUSE_REASON_PLAYER_MENU)
		TimeManager.resume(_PAUSE_REASON_DIALOGUE)
		TimeManager.resume(_PAUSE_REASON_CUTSCENE)

	_hide_all_menus()
	if UIManager != null:
		UIManager.show(UIManager.ScreenName.HUD)

	_set_player_input_enabled(true)
	_set_npc_controllers_enabled(true)
	_set_hotbar_visible(true)
	_fade_vignette_out(0.15)


func _enter_dialogue() -> void:
	# Force-close overlays and enter full pause dialogue mode.
	_hide_all_menus()
	_set_hotbar_visible(false)
	_set_player_input_enabled(false)
	_set_npc_controllers_enabled(false)
	if TimeManager != null:
		TimeManager.pause(_PAUSE_REASON_DIALOGUE)
	get_tree().paused = true


func _exit_dialogue() -> void:
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_DIALOGUE)


func _enter_cutscene() -> void:
	# Force-close overlays and enter cutscene mode (tree running, controllers locked).
	_hide_all_menus()
	_set_hotbar_visible(false)
	_set_player_input_enabled(false)
	_set_npc_controllers_enabled(false)
	if TimeManager != null:
		TimeManager.pause(_PAUSE_REASON_CUTSCENE)
	# Ensure the tree is running so cutscene scripts can drive motion.
	get_tree().paused = false
	_fade_vignette_in(0.15)


func _exit_cutscene() -> void:
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_CUTSCENE)
	_fade_vignette_out(0.15)


func _enter_player_menu() -> void:
	if state != State.PLAYER_MENU:
		return

	# Pause gameplay but keep UI alive (UIManager and menu nodes run PROCESS_MODE_ALWAYS).
	get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(_PAUSE_REASON_PLAYER_MENU)

	var p := _get_player()
	if p != null and p.has_method("set_input_enabled"):
		p.call("set_input_enabled", false)

	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)
		UIManager.show(UIManager.ScreenName.PLAYER_MENU)


func _exit_player_menu() -> void:
	# Hide overlay.
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.PLAYER_MENU)

	# Resume time (tree pause is controlled by the next state).
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_PLAYER_MENU)

	# Best-effort re-enable input; the next state's enter() can override.
	_set_player_input_enabled(true)


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

	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.PLAYER_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)
		UIManager.show(UIManager.ScreenName.PAUSE_MENU)


func _exit_paused() -> void:
	# Resume gameplay.
	if UIManager != null:
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.show(UIManager.ScreenName.HUD)

	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_MENU)

	# Best-effort resume. Dialogue/Cutscene states override via their enter().
	get_tree().paused = false
	_set_player_input_enabled(true)
	_set_hotbar_visible(true)


func _force_unpaused() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_MENU)
		TimeManager.resume(_PAUSE_REASON_PLAYER_MENU)
		TimeManager.resume(_PAUSE_REASON_DIALOGUE)
		TimeManager.resume(_PAUSE_REASON_CUTSCENE)


func _hide_all_menus() -> void:
	if UIManager == null or not UIManager.has_method("hide"):
		return
	UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
	UIManager.hide(UIManager.ScreenName.LOAD_GAME_MENU)
	UIManager.hide(UIManager.ScreenName.MAIN_MENU)
	UIManager.hide(UIManager.ScreenName.PLAYER_MENU)
	UIManager.hide(UIManager.ScreenName.HUD)


func _set_hotbar_visible(visible: bool) -> void:
	if UIManager == null or not UIManager.has_method("get_screen_node"):
		return
	var hud := UIManager.get_screen_node(UIManager.ScreenName.HUD)
	if hud != null and is_instance_valid(hud) and hud.has_method("set_hotbar_visible"):
		hud.call("set_hotbar_visible", visible)


func _set_player_input_enabled(enabled: bool) -> void:
	# Prefer AgentBrain lookup (works even before Player is fully grouped).
	if AgentBrain != null and AgentBrain.has_method("get_agent_node"):
		var p := AgentBrain.get_agent_node(&"player")
		if p != null and p.has_method("set_input_enabled"):
			p.call("set_input_enabled", enabled)
			return
	# Fallback: group-based.
	var pg := _get_player()
	if pg != null and pg.has_method("set_input_enabled"):
		pg.call("set_input_enabled", enabled)


func _set_npc_controllers_enabled(enabled: bool) -> void:
	# Best-effort: only NPCs that implement the method are affected.
	var npcs := get_tree().get_nodes_in_group(Groups.NPC_GROUP)
	for n in npcs:
		if n != null and n.has_method("set_controller_enabled"):
			n.call("set_controller_enabled", enabled)


func _fade_vignette_in(duration: float = 0.15) -> void:
	if UIManager == null:
		return
	if UIManager.has_method("show"):
		var v := UIManager.show(UIManager.ScreenName.VIGNETTE)
		if v != null and v.has_method("fade_in"):
			v.call("fade_in", maxf(0.0, duration))


func _fade_vignette_out(duration: float = 0.15) -> void:
	if UIManager == null or not UIManager.has_method("get_screen_node"):
		return
	var v := UIManager.get_screen_node(UIManager.ScreenName.VIGNETTE)
	if v != null and is_instance_valid(v) and v.has_method("fade_out"):
		v.call("fade_out", maxf(0.0, duration))


func apply_world_mode_effects() -> void:
	# Re-apply controller/UI locks after loading/spawn (e.g. new Player instance).
	# This is intentionally limited to world-mode states and should be idempotent.
	match state:
		State.DIALOGUE:
			_set_player_input_enabled(false)
			_set_npc_controllers_enabled(false)
			_set_hotbar_visible(false)
			get_tree().paused = true
		State.CUTSCENE:
			_set_player_input_enabled(false)
			_set_npc_controllers_enabled(false)
			_set_hotbar_visible(false)
			get_tree().paused = false
		State.IN_GAME:
			_set_player_input_enabled(true)
			_set_npc_controllers_enabled(true)
			_set_hotbar_visible(true)
		_:
			pass


func _on_scene_loading_started() -> void:
	_external_loading_depth += 1
	# Ensure controllers are locked during scene loads (best-effort).
	_set_player_input_enabled(false)
	_set_npc_controllers_enabled(false)


func _on_scene_loading_finished() -> void:
	_external_loading_depth = max(0, _external_loading_depth - 1)
	if _external_loading_depth > 0:
		return
	apply_world_mode_effects()


func _get_player() -> Node:
	var nodes := get_tree().get_nodes_in_group(Groups.PLAYER)
	if nodes.is_empty():
		return null
	return nodes[0] as Node


func toggle_player_menu() -> void:
	if _transitioning:
		return

	# Only allow opening while actively playing.
	if state == State.IN_GAME:
		_set_state(State.PLAYER_MENU)
	elif state == State.PLAYER_MENU:
		_set_state(State.IN_GAME)
