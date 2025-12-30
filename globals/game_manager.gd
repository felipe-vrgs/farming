extends Node


const LEVEL_SCENES: Dictionary[Enums.Levels, String] = {
	Enums.Levels.ISLAND: "res://levels/island.tscn",
	Enums.Levels.NPC_HOUSE: "res://levels/npc_house.tscn",
}

const _LOADING_SCREEN_SCENE := preload("res://ui/loading_screen/loading_screen.tscn")
const _LEVEL_CAPTURE := preload("res://world/capture/level_capture.gd")
const _LEVEL_HYDRATOR := preload("res://world/hydrate/level_hydrator.gd")
const _OFFLINE_SIMULATION := preload("res://world/simulation/offline_simulation.gd")

# Player position can be restored before the Player node joins the "player" group.
var _pending_player_pos_set: bool = false
var _pending_player_pos: Vector2 = Vector2.ZERO
var _pending_player_pos_attempts: int = 0

func _ready() -> void:
	if EventBus:
		EventBus.day_started.connect(_on_day_started)

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
			and GridState
			and GridState.ensure_initialized()):
			return
		await get_tree().process_frame

# region Player helpers
func _get_player_node() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	var n = nodes[0]
	return n as Node2D

func get_player_pos() -> Vector2:
	var p := _get_player_node()
	return p.global_position if p != null else Vector2.ZERO

func set_player_pos(pos: Vector2) -> void:
	# Position can legitimately be Vector2.ZERO, so never early-return on that.
	_pending_player_pos = pos
	_pending_player_pos_set = true
	_pending_player_pos_attempts = 0
	_try_apply_pending_player_pos()

func _try_apply_pending_player_pos() -> void:
	if not _pending_player_pos_set:
		return
	var p := _get_player_node()
	if p != null:
		p.global_position = _pending_player_pos
		_pending_player_pos_set = false
		return

	# Retry a few frames; Player may not be ready yet (group not assigned).
	_pending_player_pos_attempts += 1
	if _pending_player_pos_attempts > 20:
		# Give up silently; next restore can try again.
		return
	call_deferred("_try_apply_pending_player_pos")

# endregion

func start_new_game() -> void:
	if SaveManager == null:
		return

	var loading_screen = _LOADING_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(loading_screen)
	await loading_screen.fade_out()

	SaveManager.reset_session()

	if TimeManager:
		TimeManager.reset()

	var start_level := Enums.Levels.ISLAND
	var ok := await change_level_scene(start_level)
	if not ok:
		await loading_screen.fade_in()
		loading_screen.queue_free()
		return

	var gs := GameSave.new()
	gs.active_level_id = start_level
	gs.current_day = 1
	SaveManager.save_session_game_save(gs)

	await loading_screen.fade_in()
	loading_screen.queue_free()

func autosave_session() -> bool:
	# Snapshot runtime -> session files (active level + game meta).
	if SaveManager == null:
		return false
	var lr := get_active_level_root()
	if lr == null or GridState == null:
		return false
	var ls: LevelSave = _LEVEL_CAPTURE.capture(lr, GridState, get_player_pos())
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

	var ok := await change_level_scene(gs.active_level_id)
	if not ok:
		await loading_screen.fade_in()
		loading_screen.queue_free()
		return false

	var ls := SaveManager.load_session_level_save(gs.active_level_id)
	if ls != null:
		var lr := get_active_level_root()
		if lr != null:
			_LEVEL_HYDRATOR.hydrate(GridState, lr, ls)
		set_player_pos(ls.player_pos)

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

func travel_to_level(level_id: Enums.Levels, spawn_tag: String = "") -> bool:
	if SaveManager == null:
		return false
	var loading_screen := _LOADING_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(loading_screen)
	await loading_screen.fade_out()

	# Autosave current session before leaving.
	autosave_session()

	var ok := await change_level_scene(level_id)
	if ok:
		var ls := SaveManager.load_session_level_save(level_id)
		if ls != null:
			var lr := get_active_level_root()
			if lr != null:
				_LEVEL_HYDRATOR.hydrate(GridState, lr, ls)

		# Determine player placement.
		var target_pos: Variant = null

		# 1) Try spawn tag (e.g. from a TravelZone).
		if not spawn_tag.is_empty():
			var lr := get_active_level_root()
			if lr:
				var spawn_node := lr.find_child(spawn_tag, true, false)
				if spawn_node is Node2D:
					target_pos = spawn_node.global_position

		# 2) Fallback to saved position.
		if target_pos == null and ls != null:
			target_pos = ls.player_pos

		# 3) Apply if we have a position.
		if target_pos != null:
			set_player_pos(target_pos)

		# Update session meta.
		var gs := SaveManager.load_session_game_save()
		if gs == null:
			gs = GameSave.new()
		gs.active_level_id = level_id
		if TimeManager:
			gs.current_day = int(TimeManager.current_day)
		SaveManager.save_session_game_save(gs)

	await loading_screen.fade_in()
	loading_screen.queue_free()
	return ok

func _on_day_started(_day_index: int) -> void:
	if GridState != null and GridState.has_method("apply_day_started"):
		GridState.apply_day_started(_day_index)

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
		_OFFLINE_SIMULATION.compute_offline_day_for_level_save(ls)
		SaveManager.save_session_level_save(ls)

	# Let everything else react after runtime + persistence are consistent.
	if EventBus:
		EventBus.day_tick_completed.emit(_day_index)
