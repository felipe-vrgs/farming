extends Node

# Runtime-owned dependencies.
var active_level_id: Enums.Levels = Enums.Levels.NONE
var save_manager: Node = null
var game_flow: Node = null
var flow_manager: Node = null
var scene_loader: Node = null

# Accessors for delegated state
var flow_state: Enums.FlowState:
	get:
		return flow_manager.flow_state if flow_manager else Enums.FlowState.RUNNING


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
	await scene_loader.bind_active_level_when_ready()
	flow_manager.apply_flow_state()


func _ensure_dependencies() -> void:
	if save_manager == null or not is_instance_valid(save_manager):
		save_manager = _ensure_child("SaveManager", "res://globals/game_flow/save/save_manager.gd")

	if game_flow == null or not is_instance_valid(game_flow):
		game_flow = _ensure_child("GameFlow", "res://globals/game_flow/game_flow.gd")

	if flow_manager == null or not is_instance_valid(flow_manager):
		flow_manager = _ensure_child(
			"FlowStateManager", "res://globals/game_flow/flow_state_manager.gd"
		)
		flow_manager.setup(self)

	if scene_loader == null or not is_instance_valid(scene_loader):
		scene_loader = _ensure_child("SceneLoader", "res://globals/game_flow/scene_loader.gd")
		scene_loader.setup(self)

		# Connect loading signals to flow manager
		if not scene_loader.loading_started.is_connected(flow_manager._on_loading_started):
			scene_loader.loading_started.connect(flow_manager._on_loading_started)
		if not scene_loader.loading_finished.is_connected(flow_manager._on_loading_finished):
			scene_loader.loading_finished.connect(flow_manager._on_loading_finished)


func _ensure_child(node_name: String, script_path: String) -> Node:
	var existing := get_node_or_null(NodePath(node_name))
	if existing != null:
		return existing
	var node = load(script_path).new()
	node.name = node_name
	add_child(node)
	return node


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		autosave_session()
		get_tree().quit()


func get_active_level_root() -> LevelRoot:
	var scene := get_tree().current_scene
	if scene is LevelRoot:
		return scene as LevelRoot
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
	active_level_id = next
	if next == Enums.Levels.NONE:
		scene_loader.unbind_active_level()


func change_level_scene(level_id: Enums.Levels) -> bool:
	return await scene_loader.change_level_scene(level_id)


# region Cutscene helpers
func find_cutscene_anchor(anchor_name: StringName) -> Node2D:
	if String(anchor_name).is_empty():
		return null
	var lr := get_active_level_root()
	if lr == null:
		return null
	var anchors := lr.get_node_or_null(NodePath("CutsceneAnchors"))
	if anchors == null:
		return null
	var n := anchors.get_node_or_null(NodePath(String(anchor_name)))
	return n as Node2D


func find_agent_by_id(agent_id: StringName) -> Node2D:
	if AgentBrain == null:
		return null
	return AgentBrain.get_agent_node(agent_id)


# endregion


func start_new_game() -> bool:
	_ensure_dependencies()
	scene_loader.begin_loading()

	save_manager.reset_session()
	if AgentBrain.registry != null:
		AgentBrain.registry.load_from_session(save_manager.load_session_agents_save())

	if TimeManager:
		TimeManager.reset()

	var start_level := Enums.Levels.ISLAND
	var ok := await change_level_scene(start_level)
	if not ok:
		scene_loader.end_loading()
		return false
	var lr := get_active_level_root()
	if lr == null:
		scene_loader.end_loading()
		return false
	_set_active_level_id(lr.level_id)
	if AgentBrain.spawner != null:
		AgentBrain.spawner.seed_player_for_new_game(lr)
		AgentBrain.spawner.sync_agents_for_active_level(lr)
	if AgentBrain.registry != null:
		var a = AgentBrain.registry.save_to_session()
		if a != null:
			save_manager.save_session_agents_save(a)
	var gs := GameSave.new()
	gs.active_level_id = start_level
	gs.current_day = 1
	gs.minute_of_day = 0
	save_manager.save_session_game_save(gs)
	scene_loader.end_loading()
	return true


func autosave_session() -> bool:
	if flow_state != Enums.FlowState.RUNNING:
		return false
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

	if AgentBrain.registry != null:
		if AgentBrain.spawner != null:
			AgentBrain.spawner.capture_spawned_agents()
		var p := find_agent_by_id(&"player")
		if p != null:
			AgentBrain.registry.capture_record_from_node(p)
		var a = AgentBrain.registry.save_to_session()
		if a != null:
			save_manager.save_session_agents_save(a)

	if DialogueManager != null:
		var ds := DialogueManager.capture_state()
		if ds != null:
			save_manager.save_session_dialogue_save(ds)

	return true


func continue_session() -> bool:
	_ensure_dependencies()
	scene_loader.begin_loading()

	var gs = save_manager.load_session_game_save()
	if gs == null:
		scene_loader.end_loading()
		return false

	if AgentBrain.registry != null:
		AgentBrain.registry.load_from_session(save_manager.load_session_agents_save())

	var ds: DialogueSave = save_manager.load_session_dialogue_save()
	if ds != null and DialogueManager != null:
		DialogueManager.hydrate_state(ds)

	if TimeManager:
		TimeManager.current_day = int(gs.current_day)
		TimeManager.set_minute_of_day(int(gs.minute_of_day))

	var ok := await change_level_scene(gs.active_level_id)
	if not ok:
		scene_loader.end_loading()
		return false

	var ls = save_manager.load_session_level_save(gs.active_level_id)
	var lr := get_active_level_root()
	if lr == null:
		scene_loader.end_loading()
		return false
	_set_active_level_id(lr.level_id)
	if ls != null:
		LevelHydrator.hydrate(WorldGrid, lr, ls)
	if AgentBrain.spawner != null:
		AgentBrain.spawner.sync_all(lr)

	autosave_session()
	scene_loader.end_loading()
	return true


func save_to_slot(slot: String = "default") -> bool:
	_ensure_dependencies()
	if not autosave_session():
		return false
	return save_manager.copy_session_to_slot(slot)


func load_from_slot(slot: String = "default") -> bool:
	_ensure_dependencies()
	scene_loader.begin_loading()

	if not save_manager.copy_slot_to_session(slot):
		scene_loader.end_loading()
		return false

	var ok := await continue_session()
	scene_loader.end_loading()
	return ok


func perform_level_change(
	target_level_id: Enums.Levels, fallback_spawn_point: SpawnPointData = null
) -> bool:
	_ensure_dependencies()
	scene_loader.begin_loading()
	autosave_session()

	var ok := await change_level_scene(target_level_id)
	if not ok:
		scene_loader.end_loading()
		return false

	var lr := get_active_level_root()
	if lr == null:
		scene_loader.end_loading()
		return false
	_set_active_level_id(lr.level_id)

	var ls = save_manager.load_session_level_save(target_level_id)
	if ls != null:
		LevelHydrator.hydrate(WorldGrid, lr, ls)

	if AgentBrain.spawner != null:
		AgentBrain.spawner.sync_all(lr, fallback_spawn_point)
		flow_manager.apply_flow_state()

	var gs = save_manager.load_session_game_save()
	if gs == null:
		gs = GameSave.new()
	gs.active_level_id = target_level_id
	if TimeManager:
		gs.current_day = int(TimeManager.current_day)
		gs.minute_of_day = int(TimeManager.get_minute_of_day())
	save_manager.save_session_game_save(gs)
	scene_loader.end_loading()
	return true


func perform_level_warp(
	target_level_id: Enums.Levels, fallback_spawn_point: SpawnPointData = null
) -> bool:
	_ensure_dependencies()
	scene_loader.begin_loading()

	var ok := await change_level_scene(target_level_id)
	if not ok:
		scene_loader.end_loading()
		return false

	var lr := get_active_level_root()
	if lr == null:
		scene_loader.end_loading()
		return false
	_set_active_level_id(lr.level_id)

	var ls = save_manager.load_session_level_save(target_level_id)
	if ls != null:
		LevelHydrator.hydrate(WorldGrid, lr, ls)

	if AgentBrain.spawner != null:
		AgentBrain.spawner.sync_all(lr, fallback_spawn_point)
		flow_manager.apply_flow_state()

	scene_loader.end_loading()
	return true


func _on_day_started(_day_index: int) -> void:
	if WorldGrid != null:
		WorldGrid.apply_day_started(_day_index)

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

	if EventBus:
		EventBus.day_tick_completed.emit(_day_index)
