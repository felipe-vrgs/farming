extends Node

const LEVEL_SCENES: Dictionary[Enums.Levels, String] = {
	Enums.Levels.ISLAND: "res://levels/island.tscn",
	Enums.Levels.FRIEREN_HOUSE: "res://levels/frieren_house.tscn",
}

const _PAUSE_REASON_LOADING := &"loading"
const _PAUSE_REASON_CUTSCENE := &"cutscene"
const _PAUSE_REASON_DIALOGUE := &"dialogue"

## World-mode flow state (orthogonal to GameFlow menu/pause).
var flow_state: Enums.FlowState = Enums.FlowState.RUNNING

# Runtime-owned dependencies (no longer autoloaded).
# Callers should use:
# - Runtime.save_manager.some_method()
# - Runtime.game_flow.some_method()
var active_level_id: Enums.Levels = Enums.Levels.NONE
var save_manager: Node = null
var game_flow: Node = null
var _loading_depth: int = 0

## Cache of whether SceneTree was paused before entering dialogue mode.
var _tree_paused_before_dialogue: bool = false

func _enter_tree() -> void:
	_ensure_dependencies()

func _ready() -> void:
	_ensure_dependencies()

	if EventBus:
		EventBus.day_started.connect(_on_day_started)
		if not EventBus.active_level_changed.is_connected(_on_active_level_changed):
			EventBus.active_level_changed.connect(_on_active_level_changed)

	# Best-effort initialize on boot (if starting directly in a level).
	var lr := get_active_level_root()
	if lr != null:
		_set_active_level_id(lr.level_id)
		call_deferred("_try_bind_boot_level")

func _try_bind_boot_level() -> void:
	await _bind_active_level_when_ready()
	# If we are in a special flow state (dialogue/cutscene), re-apply on boot bind
	# so newly spawned nodes inherit controller locks.
	_reapply_flow_state()

func _ensure_dependencies() -> void:
	# NOTE: on script reload, member vars may reset but children may still exist.
	if save_manager == null or not is_instance_valid(save_manager):
		var existing_sm := get_node_or_null(NodePath("SaveManager"))
		if existing_sm != null:
			save_manager = existing_sm
		else:
			save_manager = preload("res://globals/game_flow/save/save_manager.gd").new()
			save_manager.name = "SaveManager"
			add_child(save_manager)

	if game_flow == null or not is_instance_valid(game_flow):
		var existing_gf := get_node_or_null(NodePath("GameFlow"))
		if existing_gf != null:
			game_flow = existing_gf
		else:
			game_flow = preload("res://globals/game_flow/game_flow.gd").new()
			game_flow.name = "GameFlow"
			add_child(game_flow)

func is_loading() -> bool:
	return _loading_depth > 0

func _begin_loading() -> void:
	_loading_depth += 1
	if _loading_depth == 1:
		# Freeze time and prevent runtime capture from mutating agent state mid-load.
		if TimeManager != null:
			TimeManager.pause(_PAUSE_REASON_LOADING)
		if AgentBrain.registry != null:
			AgentBrain.registry.set_runtime_capture_enabled(false)

func _end_loading() -> void:
	_loading_depth = max(0, _loading_depth - 1)
	if _loading_depth == 0:
		if AgentBrain.registry != null:
			AgentBrain.registry.set_runtime_capture_enabled(true)
		if TimeManager != null:
			TimeManager.resume(_PAUSE_REASON_LOADING)

func _notification(what: int) -> void:
	# Explicit autosave moment: before app quit / window close.
	# Keep save snapshots consistent by saving time + agents + level together.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		autosave_session()
		get_tree().quit()

func get_active_level_root() -> LevelRoot:
	var scene := get_tree().current_scene
	if scene is LevelRoot:
		return scene as LevelRoot
	# Optional: if you ever nest LevelRoot under a wrapper node.
	if scene != null:
		var lr = scene.get_node_or_null(NodePath("LevelRoot"))
		if lr is LevelRoot:
			return lr as LevelRoot
	return null

func get_active_level_id() -> Enums.Levels:
	return active_level_id

func _set_active_level_id(next_level_id: Enums.Levels) -> void:
	if active_level_id == next_level_id:
		return
	if EventBus != null:
		EventBus.active_level_changed.emit(active_level_id, next_level_id)

func _on_active_level_changed(_prev: Enums.Levels, next: Enums.Levels) -> void:
	# Keep local cache in sync even when other systems emit (e.g. menu -> NONE).
	active_level_id = next
	if next == Enums.Levels.NONE:
		_unbind_active_level()

func change_level_scene(level_id: Enums.Levels) -> bool:
	var level_path = LEVEL_SCENES.get(level_id, "")
	if level_path.is_empty():
		push_warning("Runtime: Unknown level_id '%s'" % level_id)
		return false

	# Change scene.
	get_tree().change_scene_to_file(level_path)
	return await _bind_active_level_when_ready()

func _bind_active_level(lr: LevelRoot) -> bool:
	if lr == null:
		return false
	if WorldGrid == null:
		return false
	return bool(WorldGrid.bind_level_root(lr))

func _bind_active_level_when_ready(max_frames: int = 10) -> bool:
	# After `change_scene_to_file`, TileMapLayers may not be ready in the same frame.
	var last_scene_name := "<null>"
	var last_scene_path := "<unknown>"
	var last_lr_level_id := Enums.Levels.NONE
	for _i in range(max_frames):
		var scene := get_tree().current_scene
		if scene != null:
			last_scene_name = scene.name
			# `scene_file_path` is empty for some instantiated scenes; keep best-effort.
			if "scene_file_path" in scene and String(scene.scene_file_path) != "":
				last_scene_path = String(scene.scene_file_path)
		var lr := get_active_level_root()
		if lr != null:
			last_lr_level_id = lr.level_id
		if lr != null and _bind_active_level(lr):
			# Ensure cutscene/dialogue controller rules apply after a scene bind.
			_reapply_flow_state()
			return true
		await get_tree().process_frame
	push_error(
		"Runtime: Failed to bind active level after %d frames. scene='%s' (%s), level_id='%s'. "
		% [max_frames, last_scene_name, last_scene_path, str(int(last_lr_level_id))]
	)
	return false

func _unbind_active_level() -> void:
	if WorldGrid != null:
		WorldGrid.unbind()

# region World-mode flow state (RUNNING / DIALOGUE / CUTSCENE)
func request_flow_state(next: Enums.FlowState) -> void:
	if flow_state == next:
		return

	# Guarantee a save before entering a state that disables autosaving (cutscene/dialogue).
	if flow_state == Enums.FlowState.RUNNING and next != Enums.FlowState.RUNNING:
		autosave_session()

	flow_state = next
	_apply_flow_state()

func _reapply_flow_state() -> void:
	_apply_flow_state()

func _apply_flow_state() -> void:
	# Cooperate with GameFlow pause menu: never force-unpause if user is in PAUSED.
	var is_pause_menu_active := false
	# GameFlow.State.PAUSED is currently 4; keep this logic best-effort and local.
	if game_flow != null and "state" in game_flow:
		is_pause_menu_active = int(game_flow.get("state")) == 4

	match flow_state:
		Enums.FlowState.RUNNING:
			# Resume controller input/simulation.
			_set_player_input_enabled(true)
			_set_npc_controllers_enabled(true)
			# Cutscene vignette off.
			if UIManager != null and UIManager.has_method("get_screen_node"):
				var v := UIManager.get_screen_node(UIManager.ScreenName.VIGNETTE)
				if v != null and is_instance_valid(v) and v.has_method("fade_out"):
					v.call("fade_out", 0.15)
			# HUD/hotbar on.
			_set_hotbar_visible(true)
			if TimeManager != null:
				TimeManager.resume(_PAUSE_REASON_DIALOGUE)
				TimeManager.resume(_PAUSE_REASON_CUTSCENE)
			# Only unpause the tree if it wasn't paused by something else (pause menu).
			if not is_pause_menu_active and get_tree().paused and not _tree_paused_before_dialogue:
				get_tree().paused = false
			_tree_paused_before_dialogue = false

		Enums.FlowState.DIALOGUE:
			# Full pause. UI/dialogue nodes should opt into PROCESS_MODE_ALWAYS.
			_tree_paused_before_dialogue = get_tree().paused
			_set_player_input_enabled(false)
			_set_npc_controllers_enabled(false)
			if TimeManager != null:
				TimeManager.pause(_PAUSE_REASON_DIALOGUE)
			if not is_pause_menu_active:
				get_tree().paused = true
			# HUD/hotbar off during dialogue.
			_set_hotbar_visible(false)

		Enums.FlowState.CUTSCENE:
			# Keep the SceneTree running but disable controllers so cutscene scripts
			# can move actors without AI/waypoints fighting them.
			_set_player_input_enabled(false)
			_set_npc_controllers_enabled(false)
			# Cutscene vignette on (subtle).
			if UIManager != null and UIManager.has_method("show"):
				var v := UIManager.show(UIManager.ScreenName.VIGNETTE)
				if v != null and v.has_method("fade_in"):
					v.call("fade_in", 0.15)
			# HUD/hotbar off during cutscene.
			_set_hotbar_visible(false)
			if TimeManager != null:
				TimeManager.pause(_PAUSE_REASON_CUTSCENE)
			# Ensure we are not tree-paused unless the pause menu is active.
			if not is_pause_menu_active and get_tree().paused and not _tree_paused_before_dialogue:
				get_tree().paused = false

func _set_hotbar_visible(visible: bool) -> void:
	if UIManager == null or not UIManager.has_method("get_screen_node"):
		return
	var hud := UIManager.get_screen_node(UIManager.ScreenName.HUD)
	if hud != null and is_instance_valid(hud) and hud.has_method("set_hotbar_visible"):
		hud.call("set_hotbar_visible", visible)

func _set_player_input_enabled(enabled: bool) -> void:
	var p := _get_player_node()
	if p != null and p.has_method("set_input_enabled"):
		p.call("set_input_enabled", enabled)

func _set_npc_controllers_enabled(enabled: bool) -> void:
	# Keep this best-effort: only NPCs that implement the method are affected.
	var npcs := get_tree().get_nodes_in_group(Groups.NPC_GROUP)
	for n in npcs:
		if n != null and n.has_method("set_controller_enabled"):
			n.call("set_controller_enabled", enabled)
# endregion

# region Cutscene helpers (used by Dialogic cutscene events)
func find_cutscene_anchor(anchor_name: StringName) -> Node2D:
	if String(anchor_name).is_empty():
		return null
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var anchors := scene.get_node_or_null(NodePath("CutsceneAnchors"))
	if anchors == null:
		return null
	var n := anchors.get_node_or_null(NodePath(String(anchor_name)))
	return n as Node2D

func find_agent_by_id(agent_id: StringName) -> Node2D:
	# Reserve "player" for the player entity.
	if String(agent_id).is_empty() or agent_id == &"player":
		return _get_player_node()

	for n in get_tree().get_nodes_in_group(Groups.NPC_GROUP):
		if n == null:
			continue
		if "agent_component" in n:
			var ac = n.get("agent_component")
			if ac != null and "agent_id" in ac and ac.agent_id == agent_id:
				return n as Node2D
	return null
# endregion

# region Player helpers
func _get_player_node() -> Node2D:
	var nodes := get_tree().get_nodes_in_group(Groups.PLAYER)
	if nodes.is_empty():
		return null
	var n = nodes[0]
	return n as Node2D

# endregion

func start_new_game() -> bool:
	_ensure_dependencies()
	_begin_loading()

	save_manager.reset_session()
	# Session entry: hydrate agent state once.
	# (Do NOT reload AgentRegistry during level loads; that causes warps/rewinds.)
	if AgentBrain.registry != null:
		AgentBrain.registry.load_from_session(save_manager.load_session_agents_save())

	if TimeManager:
		TimeManager.reset()

	var start_level := Enums.Levels.ISLAND
	var ok := await change_level_scene(start_level)
	if not ok:
		_end_loading()
		return false
	var lr := get_active_level_root()
	if lr == null:
		_end_loading()
		return false
	_set_active_level_id(lr.level_id)
	if AgentBrain.spawner != null:
		AgentBrain.spawner.seed_player_for_new_game(lr)
		AgentBrain.spawner.sync_agents_for_active_level(lr)
	# Persist initial agent snapshot (player + any seeded NPC records).
	if AgentBrain.registry != null:
		var a = AgentBrain.registry.save_to_session()
		if a != null:
			save_manager.save_session_agents_save(a)
	var gs := GameSave.new()
	gs.active_level_id = start_level
	gs.current_day = 1
	gs.minute_of_day = 0
	save_manager.save_session_game_save(gs)
	_end_loading()
	return true

func autosave_session() -> bool:
	# Centralized guard: never persist while a dialogue/cutscene timeline is active.
	var dialogue_active := false
	if DialogueManager != null and DialogueManager.has_method("is_active"):
		dialogue_active = bool(DialogueManager.is_active())
	if flow_state != Enums.FlowState.RUNNING or dialogue_active:
		return false
	# Snapshot runtime -> session files (active level + game meta).
	_ensure_dependencies()
	var lr := get_active_level_root()
	if lr == null or WorldGrid == null:
		return false
	var ls: LevelSave = LevelCapture.capture(lr, WorldGrid)
	if ls == null:
		return false
	if not save_manager.save_session_level_save(ls):
		return false

	var gs = save_manager.load_session_game_save()
	if gs == null:
		gs = GameSave.new()
	gs.active_level_id = lr.level_id
	if TimeManager:
		gs.current_day = int(TimeManager.current_day)
		gs.minute_of_day = int(TimeManager.get_minute_of_day())
	if not save_manager.save_session_game_save(gs):
		return false

	# Persist global agent state (player + NPCs).
	if AgentBrain.registry != null:
		if AgentBrain.spawner != null:
			AgentBrain.spawner.capture_spawned_agents()
		var p := _get_player_node()
		if p != null:
			AgentBrain.registry.capture_record_from_node(p)
		var a = AgentBrain.registry.save_to_session()
		if a != null:
			save_manager.save_session_agents_save(a)

	# Persist dialogue state.
	if DialogueManager != null:
		var ds := DialogueManager.capture_state()
		if ds != null:
			save_manager.save_session_dialogue_save(ds)

	return true

func continue_session() -> bool:
	# Resume from session autosave.
	_ensure_dependencies()
	_begin_loading()

	var gs = save_manager.load_session_game_save()
	if gs == null:
		_end_loading()
		return false

	# Session entry: hydrate agent state BEFORE spawning/syncing.
	if AgentBrain.registry != null:
		AgentBrain.registry.load_from_session(save_manager.load_session_agents_save())

	# Hydrate dialogue state.
	var ds: DialogueSave = save_manager.load_session_dialogue_save()
	if ds != null and DialogueManager != null:
		DialogueManager.hydrate_state(ds)

	if TimeManager:
		TimeManager.current_day = int(gs.current_day)
		TimeManager.set_minute_of_day(int(gs.minute_of_day))

	var ok := await change_level_scene(gs.active_level_id)
	if not ok:
		_end_loading()
		return false

	var ls = save_manager.load_session_level_save(gs.active_level_id)
	var lr := get_active_level_root()
	if lr == null:
		_end_loading()
		return false
	_set_active_level_id(lr.level_id)
	if ls != null:
		LevelHydrator.hydrate(WorldGrid, lr, ls)
	if AgentBrain.spawner != null:
		AgentBrain.spawner.sync_all(lr)

	# After a load/continue, write a single consistent snapshot so the session can't
	# contain a mixed state from before/after the transition.
	autosave_session()
	_end_loading()
	return true

func save_to_slot(slot: String = "default") -> bool:
	_ensure_dependencies()
	if not autosave_session():
		return false
	return save_manager.copy_session_to_slot(slot)

func load_from_slot(slot: String = "default") -> bool:
	_ensure_dependencies()
	_begin_loading()

	if not save_manager.copy_slot_to_session(slot):
		_end_loading()
		return false

	var ok := await continue_session()
	_end_loading()
	return ok

func perform_level_change(
	target_level_id: Enums.Levels,
	fallback_spawn_point: SpawnPointData = null
) -> bool:
	# No UI here. GameFlow owns the loading screen + state transitions.
	_ensure_dependencies()
	_begin_loading()
	# Autosave current session before leaving.
	autosave_session()

	var ok := await change_level_scene(target_level_id)
	if not ok:
		_end_loading()
		return false

	var lr := get_active_level_root()
	if lr == null:
		_end_loading()
		return false
	_set_active_level_id(lr.level_id)

	var ls = save_manager.load_session_level_save(target_level_id)
	if ls != null:
		LevelHydrator.hydrate(WorldGrid, lr, ls)

	if AgentBrain.spawner != null:
		AgentBrain.spawner.sync_all(lr, fallback_spawn_point)
		# If we are in CUTSCENE mode, newly spawned NPC nodes need controller locks
		# applied after syncing (they spawn with controller_enabled=true by default).
		_reapply_flow_state()

	# Update session meta.
	var gs = save_manager.load_session_game_save()
	if gs == null:
		gs = GameSave.new()
	gs.active_level_id = target_level_id
	if TimeManager:
		gs.current_day = int(TimeManager.current_day)
		gs.minute_of_day = int(TimeManager.get_minute_of_day())
	save_manager.save_session_game_save(gs)
	_end_loading()
	return true

func perform_level_warp(
	target_level_id: Enums.Levels,
	fallback_spawn_point: SpawnPointData = null
) -> bool:
	# Cutscene/dialogue-safe: change level + sync spawns WITHOUT writing any session saves.
	# Intended for timeline warps so session persistence only happens when the timeline ends.
	_ensure_dependencies()
	_begin_loading()

	var ok := await change_level_scene(target_level_id)
	if not ok:
		_end_loading()
		return false

	var lr := get_active_level_root()
	if lr == null:
		_end_loading()
		return false
	_set_active_level_id(lr.level_id)

	# Read-only hydration from session state (does not write).
	var ls = save_manager.load_session_level_save(target_level_id)
	if ls != null:
		LevelHydrator.hydrate(WorldGrid, lr, ls)

	if AgentBrain.spawner != null:
		AgentBrain.spawner.sync_all(lr, fallback_spawn_point)
		# If we are in CUTSCENE/DIALOGUE mode, newly spawned nodes need controller locks applied.
		_reapply_flow_state()

	_end_loading()
	return true

func _on_day_started(_day_index: int) -> void:
	if WorldGrid != null:
		WorldGrid.apply_day_started(_day_index)

	# Allow any visuals/events triggered by the runtime tick to settle before capturing.
	await get_tree().process_frame
	autosave_session()
	_ensure_dependencies()
	var active_id := get_active_level_id()
	for level_id in save_manager.list_session_level_ids():
		if level_id == active_id:
			continue
		var ls = save_manager.load_session_level_save(level_id)
		if ls == null:
			continue

		var adapter := OfflineEnvironmentAdapter.new(ls)
		var result := EnvironmentSimulator.simulate_day(adapter)
		adapter.apply_result(result)
		save_manager.save_session_level_save(ls)

	# Let everything else react after runtime + persistence are consistent.
	if EventBus:
		EventBus.day_tick_completed.emit(_day_index)
