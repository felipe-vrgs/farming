extends Node

## GameFlow (v1)
## Authoritative game-flow state machine.

signal state_changed(prev: StringName, next: StringName)

const _PAUSE_REASON_MENU := &"pause_menu"
const _PAUSE_REASON_PLAYER_MENU := &"player_menu"
const _PAUSE_REASON_DIALOGUE := &"dialogue"
const _PAUSE_REASON_CUTSCENE := &"cutscene"

var state: StringName = GameStateNames.BOOT
var active_level_id: Enums.Levels = Enums.Levels.NONE
var _transitioning: bool = false
var _states: Dictionary[StringName, GameState] = {}
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
	_set_state(GameStateNames.BOOT)
	if active_level_id != Enums.Levels.NONE:
		# If we booted directly into a level (Editor "Play Scene"), skip the main menu.
		_set_state(GameStateNames.IN_GAME)
	else:
		_set_state(GameStateNames.MENU)


func _init_states() -> void:
	# State nodes live in dedicated files under `game_flow/states/`.
	# They are logic nodes that operate on this GameFlow node.
	for c in get_children():
		if c is GameState:
			c.queue_free()
	_states.clear()
	_add_state(GameStateNames.BOOT, "res://game/globals/game_flow/states/boot_state.gd")
	_add_state(GameStateNames.MENU, "res://game/globals/game_flow/states/menu_state.gd")
	_add_state(GameStateNames.LOADING, "res://game/globals/game_flow/states/loading_state.gd")
	_add_state(GameStateNames.IN_GAME, "res://game/globals/game_flow/states/in_game_state.gd")
	_add_state(GameStateNames.PAUSED, "res://game/globals/game_flow/states/paused_state.gd")
	_add_state(
		GameStateNames.PLAYER_MENU, "res://game/globals/game_flow/states/player_menu_state.gd"
	)
	_add_state(GameStateNames.DIALOGUE, "res://game/globals/game_flow/states/dialogue_state.gd")
	_add_state(GameStateNames.CUTSCENE, "res://game/globals/game_flow/states/cutscene_state.gd")


func _add_state(key: StringName, script_path: String) -> void:
	var script := load(script_path)
	if script == null or not (script is Script) or not (script as Script).can_instantiate():
		push_error("GameFlow: failed to load/instantiate state script: %s" % script_path)
		return
	var st = (script as Script).new(self)
	if st == null or not (st is Node):
		push_error("GameFlow: state script did not produce a Node: %s" % script_path)
		return
	(st as Node).name = String(key)
	add_child(st)
	_states[key] = st as Node


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
		GameStateNames.DIALOGUE:
			return Enums.FlowState.DIALOGUE
		GameStateNames.CUTSCENE:
			return Enums.FlowState.CUTSCENE
		_:
			return Enums.FlowState.RUNNING


func request_flow_state(next: Enums.FlowState) -> void:
	# Public compatibility method (replaces FlowStateManager.request_flow_state).
	if next == Enums.FlowState.DIALOGUE:
		_set_state(GameStateNames.DIALOGUE)
		return
	if next == Enums.FlowState.CUTSCENE:
		_set_state(GameStateNames.CUTSCENE)
		return
	# RUNNING: return to gameplay if we were in dialogue/cutscene.
	if state == GameStateNames.DIALOGUE or state == GameStateNames.CUTSCENE:
		_set_state(GameStateNames.IN_GAME)


func _unhandled_input(event: InputEvent) -> void:
	if event == null:
		return
	if _transitioning:
		return

	var st: GameState = _states.get(state)
	if st != null:
		# States return the next state (StringName) or GameStateNames.NONE.
		var next: StringName = st.handle_unhandled_input(event)
		if next != GameStateNames.NONE:
			_set_state(next)
			return


func start_new_game() -> bool:
	var st: GameState = _states.get(state)
	if st != null:
		return await st.start_new_game()
	return false


func continue_session() -> bool:
	var st: GameState = _states.get(state)
	if st != null:
		return await st.continue_session()
	return false


func load_from_slot(slot: String) -> bool:
	# Atomic load: copy slot -> session, then hydrate from session inside ONE loading transaction.
	# This prevents \"load continues where I stopped\" bugs (copy happening outside blackout),
	# and avoids UI flicker by keeping the screen black for the whole operation.
	if Runtime == null or Runtime.save_manager == null:
		return false

	var ok := await run_loading_action(
		func() -> bool:
			if not Runtime.save_manager.copy_slot_to_session(slot):
				return false
			# Important: do not delegate through the current state (we are in LOADING here).
			return await _continue_session_from_session()
	)

	if not ok and UIManager != null:
		UIManager.show_toast("Failed to load save slot.")
	return ok


func _continue_session_from_session() -> bool:
	# Core \"hydrate from session\" logic (shared by continue + load-from-slot).
	if Runtime == null or Runtime.save_manager == null:
		return false

	var gs: GameSave = Runtime.save_manager.load_session_game_save()
	if gs == null:
		return false

	if AgentBrain.registry != null:
		AgentBrain.registry.load_from_session(Runtime.save_manager.load_session_agents_save())

	if DialogueManager != null:
		var ds: DialogueSave = Runtime.save_manager.load_session_dialogue_save()
		if ds != null:
			DialogueManager.hydrate_state(ds)

	if TimeManager != null:
		TimeManager.current_day = int(gs.current_day)
		TimeManager.set_minute_of_day(int(gs.minute_of_day))

	var options := {"level_save": Runtime.save_manager.load_session_level_save(gs.active_level_id)}
	var ok: bool = await Runtime.scene_loader.load_level_and_hydrate(gs.active_level_id, options)
	if not ok:
		return false

	# Make sure session state is coherent on disk after load.
	Runtime.autosave_session()
	return true


## Public hook: allow non-GameFlow systems (e.g. cutscenes) to reuse the loading pipeline
## without duplicating fade/menu logic.
func run_loading_action(action: Callable, preserve_dialogue_state: bool = false) -> bool:
	return await _run_loading(action, preserve_dialogue_state)


func _on_level_change_requested(
	target_level_id: Enums.Levels, fallback_spawn_point: SpawnPointData
) -> void:
	var st: GameState = _states.get(state)
	if st != null:
		await st.perform_level_change(target_level_id, fallback_spawn_point)


func return_to_main_menu() -> void:
	_set_state(GameStateNames.MENU)


#region UI actions (called by UI scripts)


func resume_game() -> void:
	_set_state(GameStateNames.IN_GAME)


func save_game_to_slot(slot: String = "default") -> void:
	var ok := false
	if Runtime != null:
		ok = Runtime.save_to_slot(slot)
	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast("Saved." if ok else "Save failed.")


func quit_to_menu() -> void:
	_set_state(GameStateNames.MENU)


func quit_game() -> void:
	if Runtime != null:
		Runtime.autosave_session()
	get_tree().quit()


#endregion


func _run_loading(action: Callable, preserve_dialogue_state: bool = false) -> bool:
	if _transitioning:
		return false
	_transitioning = true

	_set_state(GameStateNames.LOADING)

	var ok: bool = await LoadingTransaction.run(get_tree(), action, preserve_dialogue_state)
	# If a load succeeded, we should now be in a level scene.
	if ok:
		_set_state(GameStateNames.IN_GAME)
	else:
		_set_state(GameStateNames.MENU)

	_transitioning = false
	return ok


func _set_state(next_key: StringName) -> void:
	if (
		_transitioning
		and next_key != GameStateNames.PAUSED
		and next_key != GameStateNames.IN_GAME
		and next_key != GameStateNames.LOADING
		and next_key != GameStateNames.MENU
	):
		# Allow essential flow transitions (LOADING/MENU/IN_GAME) and pause toggles even
		# while the async loading pipeline is active.
		return

	if state == next_key:
		return

	var was_transitioning := _transitioning
	_transitioning = true
	force_unpaused()

	var prev := state
	var prev_state: GameState = _states.get(prev)
	if prev_state != null:
		prev_state.exit(next_key)

	_emit_state_change(next_key)

	var next_state: GameState = _states.get(next_key)
	if next_state != null:
		next_state.enter(prev)

	_transitioning = was_transitioning


func _emit_state_change(next: StringName) -> void:
	var prev := state
	state = next
	state_changed.emit(prev, next)


func force_unpaused() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_MENU)
		TimeManager.resume(_PAUSE_REASON_PLAYER_MENU)
		TimeManager.resume(_PAUSE_REASON_DIALOGUE)
		TimeManager.resume(_PAUSE_REASON_CUTSCENE)


func _on_scene_loading_started() -> void:
	_external_loading_depth += 1
	# Ensure controllers are locked during scene loads (best-effort).
	GameplayUtils.set_player_input_enabled(get_tree(), false)
	GameplayUtils.set_npc_controllers_enabled(get_tree(), false)


func _on_scene_loading_finished() -> void:
	_external_loading_depth = max(0, _external_loading_depth - 1)
	if _external_loading_depth > 0:
		return

	var st: GameState = _states.get(state)
	if st != null:
		st.refresh()


func get_player() -> Node:
	var nodes := get_tree().get_nodes_in_group(Groups.PLAYER)
	if nodes.is_empty():
		return null
	return nodes[0] as Node


func toggle_player_menu() -> void:
	if _transitioning:
		return

	# Only allow opening while actively playing.
	if state == GameStateNames.IN_GAME:
		_set_state(GameStateNames.PLAYER_MENU)
	elif state == GameStateNames.PLAYER_MENU:
		_set_state(GameStateNames.IN_GAME)
