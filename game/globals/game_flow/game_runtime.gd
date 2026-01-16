extends Node

const START_GAME_TIME_MINUTES := 6 * 60

const _AUTO_SLEEP_REASON := &"auto_sleep"
const _SPAWN_CATALOG = preload("res://game/data/spawn_points/spawn_catalog.tres")
const _MODAL_MESSAGE_SCENE: PackedScene = preload("res://game/ui/modal_message/modal_message.tscn")

@export_group("Forced Sleep")
@export var forced_sleep_fade_in_seconds: float = 0.6
@export var forced_sleep_hold_black_seconds: float = 0.25
@export var forced_sleep_hold_after_tick_seconds: float = 0.15
@export var forced_sleep_fade_out_seconds: float = 0.6
@export_multiline var forced_sleep_message: String = (
	"You push yourself too hard and collapse from exhaustion."
	+ "\n\nWhen you wake up, you find yourself back at home."
)

# Runtime-owned dependencies.
var active_level_id: Enums.Levels = Enums.Levels.NONE
var save_manager: Node = null
var game_flow: Node = null
var scene_loader: Node = null
var _shop_vendor_id: StringName = &""
var _blacksmith_vendor_id: StringName = &""

# Forced-sleep state.
var _auto_sleep_in_progress: bool = false
var _night_start_in_blackout: bool = false
var _night_mode_pending: bool = false
var _sleep_flow_active: bool = false
var _night_flow_active: bool = false
var _sleep_block_saves: bool = false
var _continue_restore_active: bool = false

# Accessors for delegated state
var flow_state: Enums.FlowState:
	get:
		if game_flow != null:
			# Enums are int-backed in GDScript; just return the numeric value.
			return game_flow.get_flow_state()
		return Enums.FlowState.RUNNING


func _enter_tree() -> void:
	_ensure_dependencies()


func _ready() -> void:
	_ensure_dependencies()

	if EventBus:
		EventBus.day_started.connect(_on_day_started)
		if not EventBus.active_level_changed.is_connected(_on_active_level_changed):
			EventBus.active_level_changed.connect(_on_active_level_changed)

	# Clock-domain ownership: TimeManager emits forced_sleep_requested.
	if TimeManager:
		if not TimeManager.forced_sleep_requested.is_connected(_on_forced_sleep_requested):
			TimeManager.forced_sleep_requested.connect(_on_forced_sleep_requested)

	# Best-effort initialize on boot (if starting directly in a level).
	var lr := get_active_level_root()
	if lr != null:
		_set_active_level_id(lr.level_id)
		call_deferred("_try_bind_boot_level")

	if game_flow != null:
		var cb := Callable(self, "_on_game_state_changed")
		if game_flow.has_signal("base_state_changed"):
			if not game_flow.is_connected("base_state_changed", cb):
				game_flow.connect("base_state_changed", cb)
		elif game_flow.has_signal("state_changed"):
			if not game_flow.is_connected("state_changed", cb):
				game_flow.connect("state_changed", cb)


func _try_bind_boot_level() -> void:
	await scene_loader.bind_active_level_when_ready()


func _ensure_dependencies() -> void:
	if save_manager == null or not is_instance_valid(save_manager):
		save_manager = _ensure_child(
			"SaveManager", "res://game/globals/game_flow/save/save_manager.gd"
		)

	if game_flow == null or not is_instance_valid(game_flow):
		game_flow = _ensure_child("GameFlow", "res://game/globals/game_flow/game_flow.gd")

	if scene_loader == null or not is_instance_valid(scene_loader):
		scene_loader = _ensure_child("SceneLoader", "res://game/globals/game_flow/scene_loader.gd")
		scene_loader.setup(self)

		# Connect loading signals to GameFlow (controller locks, etc.).
		if game_flow != null:
			if game_flow.has_method("_on_scene_loading_started"):
				var cb_start := Callable(game_flow, "_on_scene_loading_started")
				if not scene_loader.loading_started.is_connected(cb_start):
					scene_loader.loading_started.connect(cb_start)
			if game_flow.has_method("_on_scene_loading_finished"):
				var cb_end := Callable(game_flow, "_on_scene_loading_finished")
				if not scene_loader.loading_finished.is_connected(cb_end):
					scene_loader.loading_finished.connect(cb_end)


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


func get_tier(key: StringName, default: int = 0) -> int:
	_ensure_dependencies()
	if save_manager == null:
		return default
	var gs: GameSave = save_manager.load_session_game_save()
	if gs == null:
		return default
	if gs.tiers.has(key):
		return int(gs.tiers[key])
	var key_str := String(key)
	if gs.tiers.has(key_str):
		return int(gs.tiers[key_str])
	return default


func set_tier(key: StringName, next_tier: int) -> void:
	_ensure_dependencies()
	if save_manager == null:
		return
	var tier = max(0, int(next_tier))
	var gs: GameSave = save_manager.load_session_game_save()
	if gs == null:
		gs = GameSave.new()
		gs.version = 1
	gs.tiers[key] = tier
	save_manager.save_session_game_save(gs)
	_apply_tier_to_active_level(key, tier)


func _apply_tier_to_active_level(key: StringName, tier: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(Groups.TIER_CONTROLLERS):
		if node == null or not is_instance_valid(node):
			continue
		var node_key: StringName = &""
		if "tier_key" in node:
			node_key = StringName(node.get("tier_key"))
		elif "metadata_key" in node:
			node_key = StringName(node.get("metadata_key"))
		if node_key.is_empty() or node_key != key:
			continue
		if node.has_method("set_tier"):
			node.call("set_tier", tier)


func should_start_night_mode() -> bool:
	# Placeholder for future event-driven conditions.
	if flow_state != Enums.FlowState.RUNNING:
		return false
	var day := int(TimeManager.current_day)
	if day % 2 == 0:
		return false
	return true


func is_sleep_flow_active() -> bool:
	return _sleep_flow_active


func _get_game_flow_base_state() -> StringName:
	if game_flow == null:
		return GameStateNames.NONE
	if game_flow.has_method("get_base_state"):
		var v: Variant = game_flow.call("get_base_state")
		return v if v is StringName else GameStateNames.NONE
	var v2: Variant = game_flow.get("base_state")
	return v2 if v2 is StringName else GameStateNames.NONE


func can_player_save() -> bool:
	if _sleep_block_saves:
		return false
	if flow_state != Enums.FlowState.RUNNING or DialogueManager.is_active():
		return false
	if game_flow != null:
		var st: StringName = _get_game_flow_base_state()
		if st == GameStateNames.NIGHT:
			return false
	return true


func prepare_for_session_load() -> void:
	# Autoloads persist across menu/continue; clear runtime caches before hydrate.
	_continue_restore_active = true
	_auto_sleep_in_progress = false
	_night_start_in_blackout = false
	_sleep_flow_active = false
	_night_flow_active = false
	_sleep_block_saves = false
	if DialogueManager != null and DialogueManager.has_method("stop_dialogue"):
		DialogueManager.stop_dialogue(false)
	if AgentBrain != null and AgentBrain.has_method("reset_for_new_game"):
		AgentBrain.reset_for_new_game()
	if QuestManager != null and QuestManager.has_method("reset_for_new_game"):
		QuestManager.reset_for_new_game()
	if RelationshipManager != null and RelationshipManager.has_method("reset_for_new_game"):
		RelationshipManager.reset_for_new_game()
	if DayNightManager != null and DayNightManager.has_method("clear_night_mode_multiplier"):
		DayNightManager.clear_night_mode_multiplier()
	if SFXManager != null and is_instance_valid(SFXManager):
		if SFXManager.has_method("stop_all"):
			SFXManager.stop_all()
		if SFXManager.has_method("restore_level_audio"):
			SFXManager.restore_level_audio()


func is_continue_restore_active() -> bool:
	return _continue_restore_active


func clear_continue_restore_active() -> void:
	_continue_restore_active = false


func request_bed_sleep(
	fade_in_seconds: float,
	hold_black_seconds: float,
	hold_after_tick_seconds: float,
	fade_out_seconds: float
) -> void:
	await _run_sleep_flow(
		{
			"pause_reason": &"sleep",
			"fade_in_seconds": fade_in_seconds,
			"hold_black_seconds": hold_black_seconds,
			"hold_after_tick_seconds": hold_after_tick_seconds,
			"fade_out_seconds": fade_out_seconds,
			"lock_npcs": false,
			"hide_hotbar": true,
			"use_vignette": true,
			"fade_music": true,
			"on_black": Callable(DaySummaryManager, "present_end_of_day_screen"),
		}
	)


func finish_night_flow(options: Dictionary) -> void:
	if not _sleep_flow_active:
		_sleep_flow_active = true
		_sleep_block_saves = true

	var sleep_options := options.duplicate()
	sleep_options["defer_blackout_end"] = true
	sleep_options["defer_restore"] = true
	sleep_options["advance_to_6am"] = true
	sleep_options["force_advance_day"] = true
	await SleepService.sleep_to_6am(get_tree(), sleep_options)

	if TimeManager != null:
		var minute := int(TimeManager.get_minute_of_day())
		if minute != int(TimeManager.DAY_TICK_MINUTE):
			TimeManager.set_minute_of_day(int(TimeManager.DAY_TICK_MINUTE))

	_sleep_flow_active = false
	_night_flow_active = false
	_sleep_block_saves = false


func _run_sleep_flow(options: Dictionary) -> void:
	if _sleep_flow_active:
		return
	_sleep_flow_active = true
	_sleep_block_saves = true

	var will_start_night := should_start_night_mode()
	var sleep_options := options.duplicate()
	sleep_options["defer_blackout_end"] = will_start_night
	sleep_options["defer_restore"] = will_start_night
	sleep_options["advance_to_6am"] = not will_start_night

	await SleepService.sleep_to_6am(get_tree(), sleep_options)

	if will_start_night:
		_night_flow_active = true
		call_deferred("request_night_mode_from_sleep")
	else:
		_sleep_flow_active = false
		_sleep_block_saves = false


func request_night_mode() -> void:
	_ensure_dependencies()
	if game_flow != null and game_flow.has_method("request_night_mode"):
		game_flow.call("request_night_mode")


func request_night_mode_from_sleep() -> void:
	_night_start_in_blackout = true
	request_night_mode()


func consume_night_start_in_blackout() -> bool:
	var v := _night_start_in_blackout
	_night_start_in_blackout = false
	return v


func _on_game_state_changed(_prev: StringName, next: StringName) -> void:
	if next == GameStateNames.NIGHT:
		_night_flow_active = true
		_sleep_block_saves = true
		return
	if _night_flow_active and next != GameStateNames.NIGHT:
		_night_flow_active = false
		if not _sleep_flow_active:
			_sleep_block_saves = false


func _set_active_level_id(next_level_id: Enums.Levels) -> void:
	if active_level_id == next_level_id:
		return
	if EventBus != null:
		EventBus.active_level_changed.emit(active_level_id, next_level_id)


func _on_active_level_changed(_prev: Enums.Levels, next: Enums.Levels) -> void:
	active_level_id = next
	if next == Enums.Levels.NONE:
		scene_loader.unbind_active_level()


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


func _autosave_guard() -> bool:
	if _sleep_block_saves || flow_state != Enums.FlowState.RUNNING or DialogueManager.is_active():
		return false
	var st: StringName = _get_game_flow_base_state()
	if st == GameStateNames.NIGHT:
		return false
	_ensure_dependencies()
	var lr := get_active_level_root()
	if lr == null or WorldGrid == null:
		return false

	var ls: LevelSave = LevelCapture.capture(lr, WorldGrid)
	if ls == null or not save_manager.save_session_level_save(ls):
		return false

	var gs = save_manager.load_session_game_save()
	if gs == null:
		gs = GameSave.new()
	gs.active_level_id = lr.level_id
	if TimeManager:
		gs.current_day = int(TimeManager.current_day)
		gs.minute_of_day = int(TimeManager.get_minute_of_day())
	if WeatherManager != null and WeatherManager.has_method("write_save_state"):
		WeatherManager.write_save_state(gs)
	if not save_manager.save_session_game_save(gs):
		return false

	return true


func autosave_session() -> bool:
	if not _autosave_guard():
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

	var ds := DialogueManager.capture_state()
	if ds != null:
		save_manager.save_session_dialogue_save(ds)

	if QuestManager != null and save_manager != null:
		var qs: QuestSave = QuestManager.capture_state()
		if qs != null:
			save_manager.save_session_quest_save(qs)

	if RelationshipManager != null and save_manager != null:
		var rs: RelationshipsSave = RelationshipManager.capture_state()
		if rs != null and save_manager.has_method("save_session_relationships_save"):
			save_manager.save_session_relationships_save(rs)

	return true


# region Shop helpers


func open_shop(vendor_id: StringName) -> void:
	# Store the vendor so the SHOPPING state can setup the UI.
	_shop_vendor_id = vendor_id
	if game_flow != null and game_flow.has_method("request_shop_open"):
		game_flow.call("request_shop_open")


func get_shop_vendor_id() -> StringName:
	return _shop_vendor_id


func clear_shop_vendor_id() -> void:
	_shop_vendor_id = &""


# endregion

# region Blacksmith helpers


func open_blacksmith(vendor_id: StringName = &"") -> void:
	# Store the vendor so the BLACKSMITH state can setup the UI (optional).
	_blacksmith_vendor_id = vendor_id
	if game_flow != null and game_flow.has_method("request_blacksmith_open"):
		game_flow.call("request_blacksmith_open")


func get_blacksmith_vendor_id() -> StringName:
	return _blacksmith_vendor_id


func clear_blacksmith_vendor_id() -> void:
	_blacksmith_vendor_id = &""


# endregion


func save_to_slot(slot: String = "default") -> bool:
	_ensure_dependencies()
	if not autosave_session():
		return false
	return save_manager.copy_session_to_slot(slot)


## Cutscene/dialogue helper: warp the active scene to a target level and spawn point.
## - Uses the SceneLoader hydration pipeline.
## - IMPORTANT: must NOT stop the active Dialogic timeline (cutscenes often warp mid-timeline).
## - Does NOT autosave or update GameSave (timeline-safe). Callers can autosave after.
func perform_level_warp(target_level_id: Enums.Levels, spawn_point: SpawnPointData) -> bool:
	_ensure_dependencies()
	if scene_loader == null:
		return false

	# GameFlow.run_loading_action() uses LoadingTransaction which force-stops DialogueManager,
	# so cutscene warps must bypass it.
	var was_paused := get_tree().paused
	get_tree().paused = false

	# Mark loading for systems that must not tick/persist mid-load (AgentBrain, TimeManager, etc).
	if scene_loader.has_method("begin_loading"):
		scene_loader.begin_loading()

	var options := {"spawn_point": spawn_point}
	# Pre-fetch level save if available.
	if save_manager != null:
		options["level_save"] = save_manager.load_session_level_save(target_level_id)

	var ok: bool = bool(await scene_loader.load_level_and_hydrate(target_level_id, options))

	if scene_loader.has_method("end_loading"):
		scene_loader.end_loading()

	get_tree().paused = was_paused
	return ok


func _on_day_started(_day_index: int) -> void:
	if WorldGrid != null:
		WorldGrid.apply_day_started(_day_index)

	await get_tree().process_frame

	# Day-start schedule reset (06:00): ensure all NPCs are placed into their
	# current day start schedule location/level BEFORE any persistence hooks and
	# before Sleep waits on day_tick_completed.
	if AgentBrain != null and AgentBrain.has_method("reset_npcs_to_day_start"):
		var minute := -1
		if TimeManager != null:
			minute = int(TimeManager.DAY_TICK_MINUTE)
		AgentBrain.reset_npcs_to_day_start(minute)

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


func _on_forced_sleep_requested(_day_index: int, _minute_of_day: int) -> void:
	if _auto_sleep_in_progress:
		return
	if _sleep_flow_active or _night_flow_active:
		return
	# Only enforce while actively playing in a level.
	if flow_state != Enums.FlowState.RUNNING:
		return
	if active_level_id == Enums.Levels.NONE:
		return
	# Best-effort: require a player to exist before forcing sleep.
	if find_agent_by_id(&"player") == null:
		return

	_auto_sleep_in_progress = true
	call_deferred("_run_forced_sleep_inner")


## Request a forced sleep due to exhaustion (energy depletion).
## Uses the same sleep pipeline as 2AM forced sleep.
func request_exhaustion_sleep() -> void:
	if _auto_sleep_in_progress:
		return
	if _sleep_flow_active or _night_flow_active:
		return
	# Only enforce while actively playing in a level.
	if flow_state != Enums.FlowState.RUNNING:
		return
	if active_level_id == Enums.Levels.NONE:
		return
	# Best-effort: require a player to exist before forcing sleep.
	if find_agent_by_id(&"player") == null:
		return

	_auto_sleep_in_progress = true
	call_deferred("_run_exhaustion_sleep_inner")


func _run_exhaustion_sleep_inner() -> void:
	await _run_sleep_flow(
		{
			"pause_reason": _AUTO_SLEEP_REASON,
			"fade_in_seconds": forced_sleep_fade_in_seconds,
			"hold_black_seconds": forced_sleep_hold_black_seconds,
			"hold_after_tick_seconds": forced_sleep_hold_after_tick_seconds,
			"fade_out_seconds": forced_sleep_fade_out_seconds,
			"lock_npcs": true,
			"hide_hotbar": true,
			"use_vignette": true,
			"fade_music": true,
			"on_black": Callable(self, "_on_exhaustion_sleep_black"),
		}
	)
	_auto_sleep_in_progress = false


func _on_exhaustion_sleep_black() -> void:
	# Exhaustion is a forced sleep: apply wake-up penalty before the 06:00 refill.
	_mark_player_forced_wakeup_penalty()
	await _show_forced_sleep_modal(forced_sleep_message)
	await _warp_player_to_bed_spawn()
	await get_tree().process_frame
	var dsm := get_node_or_null("/root/DaySummaryManager")
	if dsm != null and dsm.has_method("present_end_of_day_screen"):
		await dsm.call("present_end_of_day_screen", &"exhaustion")


func _run_forced_sleep_inner() -> void:
	await _run_sleep_flow(
		{
			"pause_reason": _AUTO_SLEEP_REASON,
			"fade_in_seconds": forced_sleep_fade_in_seconds,
			"hold_black_seconds": forced_sleep_hold_black_seconds,
			"hold_after_tick_seconds": forced_sleep_hold_after_tick_seconds,
			"fade_out_seconds": forced_sleep_fade_out_seconds,
			"lock_npcs": true,
			"hide_hotbar": true,
			"use_vignette": true,
			"fade_music": true,
			"on_black": Callable(self, "_on_forced_sleep_black"),
		}
	)
	_auto_sleep_in_progress = false


func _on_forced_sleep_black() -> void:
	# Modal message (above blackout).
	_mark_player_forced_wakeup_penalty()
	await _show_forced_sleep_modal(forced_sleep_message)
	# Move the player to the bed-side spawn BEFORE triggering the 06:00 day tick,
	# so day-start autosaves capture the "wake up at home" state.
	await _warp_player_to_bed_spawn()
	await get_tree().process_frame
	var dsm := get_node_or_null("/root/DaySummaryManager")
	if dsm != null and dsm.has_method("present_end_of_day_screen"):
		await dsm.call("present_end_of_day_screen", &"forced")


func _mark_player_forced_wakeup_penalty() -> void:
	var p := find_agent_by_id(&"player")
	if p == null or not is_instance_valid(p):
		return
	if "energy_component" in p and p.energy_component != null:
		var ec = p.energy_component
		if ec != null and is_instance_valid(ec) and ec.has_method("set_forced_wakeup_pending"):
			ec.call("set_forced_wakeup_pending")


func _show_forced_sleep_modal(message: String) -> void:
	# Headless/tests: best-effort timing without UI.
	if _MODAL_MESSAGE_SCENE == null or get_tree() == null or get_tree().root == null:
		return
	if UIManager == null:
		return

	var inst := _MODAL_MESSAGE_SCENE.instantiate()
	var modal := inst as ModalMessage
	if modal == null:
		inst.queue_free()
		return

	get_tree().root.add_child(modal)
	modal.set_message(message)
	await modal.confirmed


func _warp_player_to_bed_spawn() -> void:
	var sp := _SPAWN_CATALOG.player_bed if _SPAWN_CATALOG != null else null
	if sp == null or not sp.is_valid():
		return
	if scene_loader == null:
		return

	var target_level_id: Enums.Levels = sp.level_id as Enums.Levels

	# Ensure the player's record requests placement by spawn marker.
	var rec := _get_player_record()
	if rec != null:
		rec.current_level_id = target_level_id
		rec.last_spawn_point_path = sp.resource_path
		rec.needs_spawn_marker = true
		rec.last_world_pos = sp.position
		if AgentBrain != null and AgentBrain.registry != null:
			AgentBrain.registry.upsert_record(rec)

	await perform_level_warp(target_level_id, sp)


func warp_player_to_bed_spawn_for_sleep() -> void:
	await _warp_player_to_bed_spawn()


func _get_player_record() -> AgentRecord:
	if AgentBrain == null or AgentBrain.registry == null:
		return null
	var rec := AgentBrain.registry.get_record(&"player") as AgentRecord
	if rec != null:
		return rec
	# Fallback for older saves: find the first PLAYER record.
	for r in AgentBrain.registry.list_records():
		if r != null and r.kind == Enums.AgentKind.PLAYER:
			return r
	return null
