extends Node

## GameFlow (v1)
## Authoritative game-flow state machine.

signal state_changed(prev: StringName, next: StringName)
signal base_state_changed(prev: StringName, next: StringName)

const _PAUSE_REASON_MENU := &"pause_menu"
const _PAUSE_REASON_PLAYER_MENU := &"player_menu"
const _PAUSE_REASON_DIALOGUE := &"dialogue"
const _PAUSE_REASON_CUTSCENE := &"cutscene"
const _PAUSE_REASON_GRANT_REWARD := &"grant_reward"
const _PAUSE_REASON_NIGHT := &"night"

const _OVERLAY_STATES := {
	GameStateNames.PAUSED: true,
	GameStateNames.PLAYER_MENU: true,
	GameStateNames.SHOPPING: true,
	GameStateNames.BLACKSMITH: true,
	GameStateNames.GRANT_REWARD: true,
}

var state: StringName = GameStateNames.BOOT
var base_state: StringName = GameStateNames.BOOT
var active_level_id: Enums.Levels = Enums.Levels.NONE
var _transitioning: bool = false
var _states: Dictionary[StringName, GameState] = {}
var _external_loading_depth: int = 0
var _overlay_stack: Array[StringName] = []
# Player menu tab handoff: set by states, consumed by PlayerMenuState.
var _player_menu_requested_tab: int = -1
# Grant reward handoff: set by callers, consumed by GrantRewardState.
var _grant_reward_rows: Array[GrantRewardRow] = []
var _grant_reward_return_state: StringName = GameStateNames.IN_GAME
# Persisted load handoff: set during hydrate, consumed in loading completion.


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


func _is_editor_debug_scene_boot() -> bool:
	# In the editor, "Play Scene" still runs autoloads (Runtime/GameFlow/etc).
	# If we always boot into MENU, it will replace the currently played debug scene.
	# Treat any res://debug/* scene as authoritative when running from the editor.
	if not OS.has_feature("editor"):
		return false
	var scene := get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return false
	if not ("scene_file_path" in scene):
		return false
	var p := String(scene.scene_file_path)
	return p.begins_with("res://debug/")


func _on_active_level_changed(_prev: Enums.Levels, next: Enums.Levels) -> void:
	active_level_id = next


func _boot() -> void:
	_set_base_state(GameStateNames.BOOT)
	if _is_editor_debug_scene_boot():
		# Leave the current debug scene intact (no forced menu/level scene change).
		return
	if active_level_id != Enums.Levels.NONE:
		# If we booted directly into a level (Editor "Play Scene"), skip the main menu.
		_set_base_state(GameStateNames.IN_GAME)
	else:
		_set_base_state(GameStateNames.MENU)


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
	_add_state(GameStateNames.NIGHT, "res://game/globals/game_flow/states/night_state.gd")
	_add_state(GameStateNames.PAUSED, "res://game/globals/game_flow/states/paused_state.gd")
	_add_state(
		GameStateNames.PLAYER_MENU, "res://game/globals/game_flow/states/player_menu_state.gd"
	)
	_add_state(GameStateNames.SHOPPING, "res://game/globals/game_flow/states/shopping_state.gd")
	_add_state(GameStateNames.BLACKSMITH, "res://game/globals/game_flow/states/blacksmith_state.gd")
	_add_state(GameStateNames.DIALOGUE, "res://game/globals/game_flow/states/dialogue_state.gd")
	_add_state(
		GameStateNames.GRANT_REWARD, "res://game/globals/game_flow/states/grant_reward_state.gd"
	)


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


func get_active_state() -> StringName:
	return state


func get_base_state() -> StringName:
	return base_state


func has_overlay() -> bool:
	return not _overlay_stack.is_empty()


func is_overlay_state(state_key: StringName) -> bool:
	return _OVERLAY_STATES.has(state_key)


func _get_active_state_key() -> StringName:
	if _overlay_stack.is_empty():
		return base_state
	return _overlay_stack[_overlay_stack.size() - 1]


func get_flow_state() -> Enums.FlowState:
	# Compatibility layer: many systems treat this as "world mode" (RUNNING/DIALOGUE/CUTSCENE),
	# orthogonal to menu/pause overlays.
	match base_state:
		GameStateNames.DIALOGUE:
			return Enums.FlowState.DIALOGUE
		GameStateNames.CUTSCENE:
			return Enums.FlowState.CUTSCENE
		_:
			return Enums.FlowState.RUNNING


func request_flow_state(next: Enums.FlowState) -> void:
	# Public compatibility method (replaces FlowStateManager.request_flow_state).
	if next == Enums.FlowState.DIALOGUE:
		_set_base_state(GameStateNames.DIALOGUE, true)
		return
	if next == Enums.FlowState.CUTSCENE:
		_set_base_state(GameStateNames.CUTSCENE, true)
		return
	# RUNNING: return to gameplay if we were in dialogue/cutscene.
	if base_state == GameStateNames.DIALOGUE or base_state == GameStateNames.CUTSCENE:
		_set_base_state(GameStateNames.IN_GAME, true)


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
			_transition_to(next)
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
			Runtime.save_manager.set_slot(slot)
			if not Runtime.save_manager.copy_slot_to_session(slot):
				return false
			# Important: do not delegate through the current state (we are in LOADING here).
			return await _continue_session_from_session()
	)

	if not ok and UIManager != null:
		UIManager.show_toast("Failed to load save slot.")
	return ok


func load_from_session() -> bool:
	# Load the current autosave session directly (no slot copy).
	if Runtime == null or Runtime.save_manager == null:
		return false

	var ok := await run_loading_action(
		func() -> bool: return await _continue_session_from_session()
	)

	if not ok and UIManager != null:
		UIManager.show_toast("Failed to load autosave.")
	return ok


func _continue_session_from_session() -> bool:
	# Core \"hydrate from session\" logic (shared by continue + load-from-slot).
	if Runtime == null or Runtime.save_manager == null:
		return false
	if Runtime.has_method("prepare_for_session_load"):
		Runtime.prepare_for_session_load()

	var gs: GameSave = Runtime.save_manager.load_session_game_save()
	if gs == null:
		return false

	if AgentBrain.registry != null:
		AgentBrain.registry.load_from_session(Runtime.save_manager.load_session_agents_save())

	if DialogueManager != null:
		var ds: DialogueSave = Runtime.save_manager.load_session_dialogue_save()
		if ds != null:
			DialogueManager.hydrate_state(ds)

	if QuestManager != null and Runtime.save_manager != null:
		var qs: QuestSave = Runtime.save_manager.load_session_quest_save()
		if qs != null:
			QuestManager.hydrate_state(qs)
		else:
			QuestManager.reset_for_new_game()

	if RelationshipManager != null and Runtime.save_manager != null:
		var rs: RelationshipsSave = Runtime.save_manager.load_session_relationships_save()
		if rs != null:
			RelationshipManager.hydrate_state(rs)
		else:
			RelationshipManager.reset_for_new_game()

	# Ensure Dialogic quest variables follow the QuestManager rule, even if DialogueSave contained
	# older/stale quest variables.
	if DialogueManager != null:
		DialogueManager.sync_quest_state_from_manager()
		DialogueManager.sync_relationship_state_from_manager()

	if TimeManager != null:
		TimeManager.current_day = int(gs.current_day)
		TimeManager.set_minute_of_day(int(gs.minute_of_day))

	var options := {"level_save": Runtime.save_manager.load_session_level_save(gs.active_level_id)}
	var ok: bool = await Runtime.scene_loader.load_level_and_hydrate(gs.active_level_id, options)
	if not ok:
		return false

	# Post-load autosave is handled by GameFlow._run_loading() after loading ends.
	return true


## Public hook: allow non-GameFlow systems (e.g. cutscenes) to reuse the loading pipeline
## without duplicating fade/menu logic.
func run_loading_action(action: Callable, preserve_dialogue_state: bool = false) -> bool:
	return await _run_loading(action, preserve_dialogue_state, GameStateNames.IN_GAME)


func run_loading_action_to_state(
	action: Callable, return_state: StringName, preserve_dialogue_state: bool = false
) -> bool:
	return await _run_loading(action, preserve_dialogue_state, return_state)


func _on_level_change_requested(
	target_level_id: Enums.Levels, fallback_spawn_point: SpawnPointData
) -> void:
	var st: GameState = _states.get(state)
	if st != null:
		await st.perform_level_change(target_level_id, fallback_spawn_point)


func return_to_main_menu() -> void:
	_set_base_state(GameStateNames.MENU, true)


#region UI actions (called by UI scripts)


func resume_game() -> void:
	if get_active_state() == GameStateNames.PAUSED:
		var st: GameState = _states.get(GameStateNames.PAUSED)
		if st != null and st.has_method("get_return_state"):
			var return_state: Variant = st.call("get_return_state")
			if return_state is StringName and return_state != GameStateNames.NONE:
				_transition_to(return_state)
				return
	_set_base_state(GameStateNames.IN_GAME, true)


func request_grant_reward(reward_rows: Array[GrantRewardRow], return_to: StringName = &"") -> void:
	# Present rewards in a brief "modal" flow that then returns to the previous state.
	# NOTE: For now this is an opt-in API; QuestManager does not auto-invoke it.
	if _transitioning:
		return
	if reward_rows == null or reward_rows.is_empty():
		return
	_grant_reward_rows = reward_rows
	_grant_reward_return_state = (
		GameStateNames.IN_GAME if String(return_to).is_empty() else return_to
	)
	_transition_to(GameStateNames.GRANT_REWARD)


func consume_grant_reward_rows() -> Array[GrantRewardRow]:
	var rows := _grant_reward_rows
	_grant_reward_rows = []
	return rows


func consume_grant_reward_return_state() -> StringName:
	var s := _grant_reward_return_state
	_grant_reward_return_state = GameStateNames.IN_GAME
	return s


func save_game_to_slot(slot: String = "default") -> void:
	var ok := false
	if Runtime != null:
		ok = Runtime.save_to_slot(slot)
	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast("Saved." if ok else "Save failed.")


func quit_to_menu() -> void:
	_set_base_state(GameStateNames.MENU, true)


func quit_game() -> void:
	if Runtime != null:
		Runtime.autosave_session()
	get_tree().quit()


#endregion


func _run_loading(
	action: Callable, preserve_dialogue_state: bool = false, return_state: StringName = &""
) -> bool:
	if _transitioning:
		return false
	_transitioning = true
	var prev_base := base_state

	_set_base_state(GameStateNames.LOADING, true)

	# Ensure the world is quiescent during the entire loading transaction:
	# - pauses TimeManager
	# - disables AgentRegistry runtime capture (prevents mid-load persistence)
	var did_begin := false
	if Runtime != null and Runtime.scene_loader != null:
		Runtime.scene_loader.begin_loading()
		did_begin = true

	var ok: bool = await LoadingTransaction.run(get_tree(), action, preserve_dialogue_state)

	if did_begin and Runtime != null and Runtime.scene_loader != null:
		Runtime.scene_loader.end_loading()

	# If a load succeeded, we should now be in a level scene.
	var next_state := return_state
	if String(next_state).is_empty():
		# Default return state: preserve NIGHT when loading from night gameplay.
		if prev_base == GameStateNames.NIGHT:
			next_state = GameStateNames.NIGHT
		else:
			next_state = GameStateNames.IN_GAME
	if ok:
		_set_base_state(next_state, true)
	else:
		_set_base_state(GameStateNames.MENU, true)

	_transitioning = false

	# Post-load autosave: do it AFTER loading ends and after we returned to IN_GAME.
	# (Many load call-sites used to autosave inside the loading action, which can persist
	# pre-ready agent state. This keeps the autosave but makes it safe.)
	if ok and Runtime != null:
		await get_tree().process_frame
		Runtime.autosave_session()
	return ok


func _can_transition(next_key: StringName) -> bool:
	if not _transitioning:
		return true
	if next_key == GameStateNames.LOADING:
		# Always allow entering LOADING.
		return true
	if base_state == GameStateNames.LOADING:
		# During LOADING, only allow base state transitions.
		return (
			next_key == GameStateNames.MENU
			or next_key == GameStateNames.IN_GAME
			or next_key == GameStateNames.NIGHT
		)
	return false


func _transition_to(next_key: StringName) -> void:
	if next_key == GameStateNames.NONE:
		return
	if not _can_transition(next_key):
		return
	if state == next_key:
		return

	if is_overlay_state(next_key):
		if _overlay_stack.is_empty():
			_push_overlay(next_key)
			return
		if _overlay_stack.has(next_key):
			_pop_overlays_until(next_key)
			return
		_push_overlay(next_key)
		return

	_set_base_state(next_key, true)


func _set_base_state(next_key: StringName, clear_overlays: bool = true) -> void:
	if next_key == GameStateNames.NONE:
		return
	if not _can_transition(next_key):
		return

	var last_popped := GameStateNames.NONE
	if clear_overlays and not _overlay_stack.is_empty():
		last_popped = _clear_overlays(false)

	if base_state == next_key:
		if last_popped != GameStateNames.NONE:
			_call_state_on_reveal(next_key, last_popped)
		return

	var prev_base := base_state
	base_state = next_key
	base_state_changed.emit(prev_base, next_key)

	if _overlay_stack.is_empty():
		var prev_active := state
		_switch_active_state(prev_active, next_key, true, true)


func _push_overlay(next_key: StringName) -> void:
	if not is_overlay_state(next_key):
		return
	if state == next_key:
		return

	var prev_key := state
	_call_state_on_cover(prev_key, next_key)
	_overlay_stack.append(next_key)
	_switch_active_state(prev_key, next_key, false, true)


func _pop_overlay(reveal_underlying: bool = true) -> StringName:
	if _overlay_stack.is_empty():
		return GameStateNames.NONE

	var prev_key: StringName = _overlay_stack.pop_back() as StringName
	var next_key: StringName = _get_active_state_key()
	_switch_active_state(prev_key, next_key, true, false)
	if reveal_underlying:
		_call_state_on_reveal(next_key, prev_key)
	return prev_key


func _pop_overlays_until(target_key: StringName) -> void:
	if not _overlay_stack.has(target_key):
		return
	if _overlay_stack[_overlay_stack.size() - 1] == target_key:
		return

	var last_popped := GameStateNames.NONE
	while _overlay_stack.size() > 0 and _overlay_stack[_overlay_stack.size() - 1] != target_key:
		last_popped = _pop_overlay(false)
	if last_popped != GameStateNames.NONE:
		_call_state_on_reveal(target_key, last_popped)


func _clear_overlays(reveal_underlying: bool = true) -> StringName:
	var last_popped := GameStateNames.NONE
	while not _overlay_stack.is_empty():
		last_popped = _pop_overlay(false)
	if reveal_underlying and last_popped != GameStateNames.NONE:
		_call_state_on_reveal(base_state, last_popped)
	return last_popped


func _call_state_on_cover(state_key: StringName, overlay_key: StringName) -> void:
	var st: GameState = _states.get(state_key)
	if st != null and st.has_method("on_cover"):
		st.call("on_cover", overlay_key)


func _call_state_on_reveal(state_key: StringName, overlay_key: StringName) -> void:
	var st: GameState = _states.get(state_key)
	if st != null and st.has_method("on_reveal"):
		st.call("on_reveal", overlay_key)


func _switch_active_state(
	prev_key: StringName, next_key: StringName, exit_prev: bool = true, enter_next: bool = true
) -> void:
	var was_transitioning := _transitioning
	_transitioning = true
	force_unpaused()

	if exit_prev:
		var prev_state: GameState = _states.get(prev_key)
		if prev_state != null:
			prev_state.exit(next_key)

	_emit_state_change(prev_key, next_key)

	if enter_next:
		var next_state: GameState = _states.get(next_key)
		if next_state != null:
			next_state.enter(prev_key)

	_transitioning = was_transitioning


func _emit_state_change(prev: StringName, next: StringName) -> void:
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
		TimeManager.resume(_PAUSE_REASON_NIGHT)


func request_night_mode() -> void:
	if _transitioning:
		return
	# Only allow night mode from active gameplay for now.
	if get_active_state() == GameStateNames.IN_GAME:
		_set_base_state(GameStateNames.NIGHT, true)


func _on_scene_loading_started() -> void:
	_external_loading_depth += 1
	# Ensure controllers are locked during scene loads (best-effort).
	GameplayUtils.set_player_input_enabled(get_tree(), false)
	GameplayUtils.set_npc_controllers_enabled(get_tree(), false)


func _on_scene_loading_finished() -> void:
	_external_loading_depth = max(0, _external_loading_depth - 1)
	if _external_loading_depth > 0:
		return

	var st: GameState = _states.get(get_active_state())
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

	var active := get_active_state()
	# Only allow opening while actively playing.
	if active == GameStateNames.IN_GAME:
		request_player_menu(-1)
	elif active == GameStateNames.PLAYER_MENU:
		_transition_to(GameStateNames.IN_GAME)


func request_player_menu(tab: int = -1) -> void:
	if _transitioning:
		return
	_player_menu_requested_tab = int(tab)
	# Only allow opening while actively playing.
	if get_active_state() == GameStateNames.IN_GAME:
		_transition_to(GameStateNames.PLAYER_MENU)


func consume_player_menu_requested_tab() -> int:
	var v := _player_menu_requested_tab
	_player_menu_requested_tab = -1
	return int(v)


func request_shop_open() -> void:
	if _transitioning:
		return
	# Only allow opening while actively playing.
	if get_active_state() == GameStateNames.IN_GAME:
		_transition_to(GameStateNames.SHOPPING)


func request_shop_close() -> void:
	if _transitioning:
		return
	if get_active_state() == GameStateNames.SHOPPING:
		_transition_to(GameStateNames.IN_GAME)


func request_blacksmith_open() -> void:
	if _transitioning:
		return
	# Only allow opening while actively playing.
	if get_active_state() == GameStateNames.IN_GAME:
		_transition_to(GameStateNames.BLACKSMITH)


func request_blacksmith_close() -> void:
	if _transitioning:
		return
	if get_active_state() == GameStateNames.BLACKSMITH:
		_transition_to(GameStateNames.IN_GAME)
