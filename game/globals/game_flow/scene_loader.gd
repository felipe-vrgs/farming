extends Node

## SceneLoader - handles scene changing, level binding, and loading state.

signal loading_started
signal loading_finished

const LEVEL_SCENES: Dictionary[Enums.Levels, String] = {
	Enums.Levels.ISLAND: "res://game/levels/island.tscn",
	Enums.Levels.FRIEREN_HOUSE: "res://game/levels/frieren_house.tscn",
	Enums.Levels.PLAYER_HOUSE: "res://game/levels/player_house.tscn",
}

const _PAUSE_REASON_LOADING := &"loading"

var _loading_depth: int = 0
var _runtime: Node = null


func setup(runtime: Node) -> void:
	_runtime = runtime


func is_loading() -> bool:
	return _loading_depth > 0


func begin_loading() -> void:
	_loading_depth += 1
	if _loading_depth == 1:
		# Freeze time and prevent runtime capture from mutating agent state mid-load.
		if TimeManager != null:
			TimeManager.pause(_PAUSE_REASON_LOADING)
		if AgentBrain.registry != null:
			AgentBrain.registry.set_runtime_capture_enabled(false)

		loading_started.emit()


func end_loading() -> void:
	_loading_depth = max(0, _loading_depth - 1)
	if _loading_depth == 0:
		if AgentBrain.registry != null:
			AgentBrain.registry.set_runtime_capture_enabled(true)
		if TimeManager != null:
			TimeManager.resume(_PAUSE_REASON_LOADING)
		loading_finished.emit()


func change_level_scene(level_id: Enums.Levels) -> bool:
	var level_path = LEVEL_SCENES.get(level_id, "")
	if level_path.is_empty():
		push_warning("SceneLoader: Unknown level_id '%s'" % level_id)
		return false

	# Change scene.
	get_tree().change_scene_to_file(level_path)
	return await bind_active_level_when_ready()


## High-level loader: changes scene, hydrates content, and syncs agents.
## options: { "level_save": LevelSave, "spawn_point": SpawnPointData }
func load_level_and_hydrate(level_id: Enums.Levels, options: Dictionary = {}) -> bool:
	var ok := await change_level_scene(level_id)
	if not ok:
		return false

	var lr := _get_active_level_root()
	if lr == null:
		return false

	if _runtime != null and _runtime.has_method("_set_active_level_id"):
		_runtime.call("_set_active_level_id", lr.level_id)

	var ls: LevelSave = options.get("level_save")
	if ls != null:
		LevelHydrator.hydrate(WorldGrid, lr, ls)

	if AgentBrain.spawner != null:
		var sp: SpawnPointData = options.get("spawn_point")
		AgentBrain.spawner.sync_all(lr, sp)

	return true


func bind_active_level(lr: LevelRoot) -> bool:
	if lr == null:
		return false
	if WorldGrid == null:
		return false
	return bool(WorldGrid.bind_level_root(lr))


func bind_active_level_when_ready(max_frames: int = 10) -> bool:
	# After `change_scene_to_file`, TileMapLayers may not be ready in the same frame.
	var last_scene_name := "<null>"
	var last_scene_path := "<unknown>"
	var last_lr_level_id := Enums.Levels.NONE
	for _i in range(max_frames):
		var scene := get_tree().current_scene
		if scene != null:
			last_scene_name = scene.name
			if "scene_file_path" in scene and String(scene.scene_file_path) != "":
				last_scene_path = String(scene.scene_file_path)
		var lr = _get_active_level_root()
		if lr != null:
			last_lr_level_id = lr.level_id
		if lr != null and bind_active_level(lr):
			return true
		await get_tree().process_frame

	push_error(
		(
			"SceneLoader: Failed to bind active level after %d frames. scene='%s' (%s), level_id='%s'. "
			% [max_frames, last_scene_name, last_scene_path, str(int(last_lr_level_id))]
		)
	)
	return false


func unbind_active_level() -> void:
	if WorldGrid != null:
		WorldGrid.unbind()


func _get_active_level_root() -> LevelRoot:
	if _runtime != null and _runtime.has_method("get_active_level_root"):
		return _runtime.get_active_level_root()
	return null
