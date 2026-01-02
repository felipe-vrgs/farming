extends Node

const LEVEL_SCENES: Dictionary[Enums.Levels, String] = {
	Enums.Levels.ISLAND: "res://levels/island.tscn",
	Enums.Levels.FRIEREN_HOUSE: "res://levels/frieren_house.tscn",
}

const _LOADING_SCREEN_SCENE := preload("res://ui/loading_screen/loading_screen.tscn")
const _PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")

## Persist global time/meta to the session periodically, without doing a full level capture.
## This prevents "continue" restoring an old time-of-day when the player didn't travel or day-tick.
const _SESSION_META_AUTOSAVE_MIN_INTERVAL_MSEC := 5000
var _last_session_meta_autosave_msec: int = 0

func _ready() -> void:
	if EventBus:
		EventBus.day_started.connect(_on_day_started)
		EventBus.travel_requested.connect(_on_travel_requested)
	if TimeManager != null:
		TimeManager.time_changed.connect(_on_time_changed)

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
		push_warning("GameManager: Unknown level_id '%s'" % level_id)
		return false

	# Change scene.
	get_tree().change_scene_to_file(level_path)
	await get_tree().process_frame
	await _wait_for_level_runtime_ready()
	return true

func _wait_for_level_runtime_ready(max_frames: int = 10) -> void:
	# After `change_scene_to_file`, TileMapLayers may not be ready in the same frame.
	for _i in range(max_frames):
		if (TileMapManager
			and TileMapManager.ensure_initialized()
			and WorldGrid
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

func start_new_game() -> void:
	if SaveManager == null:
		return

	var loading_screen = _LOADING_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(loading_screen)
	await loading_screen.fade_out()

	SaveManager.reset_session()
	# Session entry: hydrate agent state once.
	# (Do NOT reload AgentRegistry during level loads; that causes warps/rewinds.)
	if AgentRegistry != null:
		AgentRegistry.load_from_session()

	if TimeManager:
		TimeManager.reset()

	var start_level := Enums.Levels.ISLAND
	var ok := await change_level_scene(start_level)
	if not ok:
		await loading_screen.fade_in()
		loading_screen.queue_free()
		return

	AgentSpawner.seed_player_for_new_game()
	AgentSpawner.sync_agents_for_active_level()
	var gs := GameSave.new()
	gs.active_level_id = start_level
	gs.current_day = 1
	gs.minute_of_day = 0
	SaveManager.save_session_game_save(gs)

	await loading_screen.fade_in()
	loading_screen.queue_free()

func autosave_session() -> bool:
	# Snapshot runtime -> session files (active level + game meta).
	if SaveManager == null:
		return false
	var lr := get_active_level_root()
	if lr == null or WorldGrid == null:
		return false
	var ls: LevelSave = LevelCapture.capture(lr, WorldGrid)
	if ls == null:
		return false
	if not SaveManager.save_session_level_save(ls):
		return false

	var gs := SaveManager.load_session_game_save()
	if gs == null:
		gs = GameSave.new()
	gs.active_level_id = lr.level_id
	if TimeManager:
		gs.current_day = int(TimeManager.current_day)
		gs.minute_of_day = int(TimeManager.get_minute_of_day())
	if not SaveManager.save_session_game_save(gs):
		return false

	# Persist global agent state (player + NPCs).
	if AgentRegistry != null:
		if AgentSpawner != null:
			AgentSpawner.capture_spawned_agents()
		var p := _get_player_node()
		if p != null:
			AgentRegistry.capture_record_from_node(p)
		AgentRegistry.save_to_session()
	return true

func _persist_session_game_meta() -> bool:
	# Save only `game.tres` (time + active level). This is cheap and safe to do often.
	if SaveManager == null:
		return false
	var lr := get_active_level_root()
	if lr == null:
		return false

	var gs := SaveManager.load_session_game_save()
	if gs == null:
		gs = GameSave.new()
	gs.active_level_id = lr.level_id
	if TimeManager:
		gs.current_day = int(TimeManager.current_day)
		gs.minute_of_day = int(TimeManager.get_minute_of_day())
	return SaveManager.save_session_game_save(gs)

func continue_session() -> bool:
	# Resume from session autosave.
	if SaveManager == null:
		return false

	var loading_screen = _LOADING_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(loading_screen)
	await loading_screen.fade_out()

	var gs := SaveManager.load_session_game_save()
	if gs == null:
		await loading_screen.fade_in()
		loading_screen.queue_free()
		return false

	if TimeManager:
		TimeManager.current_day = int(gs.current_day)
		TimeManager.set_minute_of_day(int(gs.minute_of_day))

	var ok := await change_level_scene(gs.active_level_id)
	if not ok:
		await loading_screen.fade_in()
		loading_screen.queue_free()
		return false

	var ls := SaveManager.load_session_level_save(gs.active_level_id)
	if ls != null:
		var lr := get_active_level_root()
		if lr != null:
			LevelHydrator.hydrate(WorldGrid, lr, ls)

	# Session entry: hydrate agent state once.
	if AgentRegistry != null:
		AgentRegistry.load_from_session()
	AgentSpawner.sync_all()
	await loading_screen.fade_in()
	loading_screen.queue_free()
	return true

func save_to_slot(slot: String = "default") -> bool:
	if SaveManager == null:
		return false
	if not autosave_session():
		return false
	return SaveManager.copy_session_to_slot(slot)

func load_from_slot(slot: String = "default") -> bool:
	if SaveManager == null:
		return false

	var loading_screen = _LOADING_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(loading_screen)
	await loading_screen.fade_out()

	if not SaveManager.copy_slot_to_session(slot):
		await loading_screen.fade_in()
		loading_screen.queue_free()
		return false

	var ok := await continue_session()
	await loading_screen.fade_in()
	loading_screen.queue_free()
	return ok

func travel_to_level(level_id: Enums.Levels) -> bool:
	if SaveManager == null:
		return false
	var loading_screen := _LOADING_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(loading_screen)
	await loading_screen.fade_out()

	# Autosave current session before leaving.
	autosave_session()

	var ok := await change_level_scene(level_id)
	if ok:
		var lr := get_active_level_root()
		if lr != null:
			var ls := SaveManager.load_session_level_save(level_id)
			if ls != null:
				LevelHydrator.hydrate(WorldGrid, lr, ls)
			AgentSpawner.sync_all()
		# Update session meta.
		var gs := SaveManager.load_session_game_save()
		if gs == null:
			gs = GameSave.new()
		gs.active_level_id = level_id
		if TimeManager:
			gs.current_day = int(TimeManager.current_day)
			gs.minute_of_day = int(TimeManager.get_minute_of_day())
		SaveManager.save_session_game_save(gs)

	await loading_screen.fade_in()
	loading_screen.queue_free()
	return ok

func _on_day_started(_day_index: int) -> void:
	if WorldGrid != null and WorldGrid.has_method("apply_day_started"):
		WorldGrid.apply_day_started(_day_index)

	# Allow any visuals/events triggered by the runtime tick to settle before capturing.
	await get_tree().process_frame
	autosave_session()

	if SaveManager == null:
		return
	var active_id := get_active_level_id()
	for level_id in SaveManager.list_session_level_ids():
		if level_id == active_id:
			continue
		var ls := SaveManager.load_session_level_save(level_id)
		if ls == null:
			continue

		var adapter := OfflineEnvironmentAdapter.new(ls)
		var result := EnvironmentSimulator.simulate_day(adapter)
		adapter.apply_result(result)
		SaveManager.save_session_level_save(ls)

	# Let everything else react after runtime + persistence are consistent.
	if EventBus:
		EventBus.day_tick_completed.emit(_day_index)

func _on_time_changed(_day_index: int, _minute_of_day: int, _day_progress: float) -> void:
	# Throttle disk writes; still keeps continue/load time consistent enough.
	var now := Time.get_ticks_msec()
	if int(now) - _last_session_meta_autosave_msec < _SESSION_META_AUTOSAVE_MIN_INTERVAL_MSEC:
		return
	_last_session_meta_autosave_msec = int(now)
	_persist_session_game_meta()

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

	var rec := AgentRegistry.ensure_agent_registered_from_node(agent) as AgentRecord
	if rec == null:
		return

	if kind == Enums.AgentKind.PLAYER:
		# Player: commit travel, then change scene.
		AgentRegistry.commit_travel_by_id(rec.agent_id, target_spawn_point)
		await travel_to_level(target_spawn_point.level_id)
		return

	# NPC travel: commit record + persist + sync agents (no scene change).
	AgentRegistry.commit_travel_and_sync(rec.agent_id, target_spawn_point)
