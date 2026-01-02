extends Node

const LEVEL_SCENES: Dictionary[Enums.Levels, String] = {
	Enums.Levels.ISLAND: "res://levels/island.tscn",
	Enums.Levels.FRIEREN_HOUSE: "res://levels/frieren_house.tscn",
}

const _PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")

const _PAUSE_REASON_LOADING := &"loading"

# Runtime-owned dependencies (no longer autoloaded).
# Callers should use:
# - Runtime.save_manager.some_method()
# - Runtime.game_flow.some_method()
var save_manager: Node = null
var game_flow: Node = null
var _loading_depth: int = 0

func _enter_tree() -> void:
	_ensure_dependencies()

func _ready() -> void:
	_ensure_dependencies()

	if EventBus:
		EventBus.day_started.connect(_on_day_started)
		EventBus.travel_requested.connect(_on_travel_requested)

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
	var lr := get_active_level_root()
	return lr.level_id if lr != null else Enums.Levels.NONE

func change_level_scene(level_id: Enums.Levels) -> bool:
	var level_path = LEVEL_SCENES.get(level_id, "")
	if level_path.is_empty():
		push_warning("Runtime: Unknown level_id '%s'" % level_id)
		return false

	# Change scene.
	get_tree().change_scene_to_file(level_path)
	await get_tree().process_frame
	await _wait_for_level_runtime_ready()
	return true

func _wait_for_level_runtime_ready(max_frames: int = 10) -> void:
	# After `change_scene_to_file`, TileMapLayers may not be ready in the same frame.
	for _i in range(max_frames):
		if (WorldGrid
			and WorldGrid.ensure_initialized()):
			return
		await get_tree().process_frame

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

func travel_to_level(level_id: Enums.Levels) -> bool:
	_ensure_dependencies()
	_begin_loading()
	var loading_screen: LoadingScreen = null
	if UIManager != null and UIManager.has_method("show"):
		loading_screen = UIManager.show(UIManager.ScreenName.LOADING_SCREEN) as LoadingScreen
	if loading_screen != null:
		await loading_screen.fade_out()

	# Autosave current session before leaving.
	autosave_session()

	var ok := await change_level_scene(level_id)
	if ok:
		var lr := get_active_level_root()
		if lr != null:
			var ls = save_manager.load_session_level_save(level_id)
			if ls != null:
				LevelHydrator.hydrate(WorldGrid, lr, ls)
			if AgentBrain.spawner != null:
				AgentBrain.spawner.sync_all(lr)
		# Update session meta.
		var gs = save_manager.load_session_game_save()
		if gs == null:
			gs = GameSave.new()
		gs.active_level_id = level_id
		if TimeManager:
			gs.current_day = int(TimeManager.current_day)
			gs.minute_of_day = int(TimeManager.get_minute_of_day())
		save_manager.save_session_game_save(gs)

	if loading_screen != null:
		await loading_screen.fade_in()
	if UIManager != null and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.LOADING_SCREEN)
	elif loading_screen != null:
		loading_screen.queue_free()

	_end_loading()
	return ok

func _on_day_started(_day_index: int) -> void:
	if WorldGrid != null and WorldGrid.has_method("apply_day_started"):
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

func _on_travel_requested(agent: Node, target_spawn_point: SpawnPointData) -> void:
	if agent == null or target_spawn_point == null or not target_spawn_point.is_valid():
		return

	# Determine agent kind via AgentComponent (preferred), otherwise fall back to group.
	var kind: Enums.AgentKind = Enums.AgentKind.NONE
	var ac := ComponentFinder.find_component_in_group(agent, Groups.AGENT_COMPONENTS)
	if ac is AgentComponent:
		kind = (ac as AgentComponent).kind
	elif agent.is_in_group("player"):
		kind = Enums.AgentKind.PLAYER

	if AgentBrain.registry == null:
		return

	var rec := AgentBrain.registry.ensure_agent_registered_from_node(agent) as AgentRecord
	if rec == null:
		return

	if kind == Enums.AgentKind.PLAYER:
		# Player: commit travel, then change scene.
		AgentBrain.registry.commit_travel_by_id(rec.agent_id, target_spawn_point)
		await travel_to_level(target_spawn_point.level_id)
		return

	# NPC travel: commit record + persist + sync agents (no scene change).
	AgentBrain.commit_travel_and_sync(rec.agent_id, target_spawn_point)
