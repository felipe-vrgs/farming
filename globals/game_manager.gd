extends Node


const LEVEL_SCENES := {
	&"island": "res://levels/island.tscn",
	&"npc_house": "res://levels/npc_house.tscn",
}

const _LOADING_SCREEN_SCENE := preload("res://ui/loading_screen/loading_screen.tscn")
const _LEVEL_CAPTURE := preload("res://world/capture/level_capture.gd")
const _LEVEL_HYDRATOR := preload("res://world/hydrate/level_hydrator.gd")

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

func get_active_level_id() -> StringName:
	var lr := get_active_level_root()
	return lr.level_id if lr != null else &""

func change_level_scene(level_id: StringName) -> bool:
	var level_path := String(LEVEL_SCENES.get(level_id, ""))
	if level_path.is_empty():
		push_warning("GameManager: Unknown level_id '%s'" % String(level_id))
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

## Computes one "day tick" for an unloaded level save (mutates `ls` in-place).
## Persistence layer (SaveManager) decides when/where to apply and store it.
func compute_offline_day_for_level_save(ls: LevelSave) -> void:
	# 1) Identify wet cells and dry them.
	var wet := {} # Vector2i -> true
	for cs in ls.cells:
		if cs == null:
			continue

		# Apply soil decay rules
		var old_t := int(cs.terrain_id)
		var new_t := SimulationRules.predict_soil_decay(old_t)

		if old_t == int(GridCellData.TerrainType.SOIL_WET):
			wet[cs.coords] = true

		if old_t != new_t:
			cs.terrain_id = new_t

	# 2) Grow plants that were wet.
	for es in ls.entities:
		if es == null:
			continue
		if int(es.entity_type) != int(Enums.EntityType.PLANT):
			continue

		# Check if plant was on wet soil
		if not wet.has(es.grid_pos):
			continue

		var plant_path := String(es.state.get("plant_data_path", ""))
		if plant_path.is_empty():
			continue
		var res = load(plant_path)
		if not (res is PlantData):
			continue
		var pd := res as PlantData

		var current_days := int(es.state.get("days_grown", 0))
		var new_days := SimulationRules.predict_plant_growth(current_days, pd.days_to_grow, true)

		if current_days != new_days:
			es.state["days_grown"] = new_days

func start_new_game() -> void:
	if SaveManager == null:
		return

	var loading_screen = _LOADING_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(loading_screen)
	await loading_screen.fade_out()

	SaveManager.reset_session()

	if TimeManager:
		TimeManager.reset()

	var start_level := &"island"
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
	if lr == null:
		return false
	if GridState == null or not GridState.ensure_initialized():
		return false

	var ls: LevelSave = _LEVEL_CAPTURE.capture(GridState, lr.level_id, get_player_pos())
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
		_LEVEL_HYDRATOR.hydrate(GridState, ls)
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

func travel_to_level(level_id: StringName) -> bool:
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
			_LEVEL_HYDRATOR.hydrate(GridState, ls)
			set_player_pos(ls.player_pos)

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
	# Let runtime systems (active level) react to day start first.
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
		compute_offline_day_for_level_save(ls)
		SaveManager.save_session_level_save(ls)
