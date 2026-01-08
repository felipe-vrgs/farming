extends GameState

const _SPAWN_CATALOG = preload("res://game/data/spawn_points/spawn_catalog.tres")


func enter(_prev: StringName = &"") -> void:
	if flow == null:
		return

	flow.force_unpaused()
	if UIManager != null:
		UIManager.hide_all_menus()

	if Runtime != null:
		Runtime.autosave_session()
	if DialogueManager != null:
		DialogueManager.stop_dialogue()
	if EventBus != null and flow.active_level_id != Enums.Levels.NONE:
		EventBus.active_level_changed.emit(flow.active_level_id, Enums.Levels.NONE)

	flow.get_tree().change_scene_to_file("res://main.tscn")
	if UIManager != null and UIManager.has_method("show"):
		UIManager.show(UIManager.ScreenName.MAIN_MENU)


func start_new_game() -> bool:
	return await flow.run_loading_action(func() -> bool: return await _start_new_game_inner())


func _start_new_game_inner() -> bool:
	if Runtime == null or Runtime.save_manager == null or Runtime.scene_loader == null:
		return false

	# Autoloads persist across "Quit to Menu" - ensure agent state is fully reset.
	if AgentBrain != null and AgentBrain.has_method("reset_for_new_game"):
		AgentBrain.reset_for_new_game()
	if QuestManager != null:
		QuestManager.reset_for_new_game()
		QuestManager.start_unlocked_quests_on_new_game()

	Runtime.save_manager.reset_session()

	if AgentBrain.registry != null:
		AgentBrain.registry.load_from_session(Runtime.save_manager.load_session_agents_save())

	if TimeManager:
		TimeManager.reset()
		# Default start time: 06:00
		TimeManager.set_minute_of_day(6 * 60)

	# New game starts at the configured player spawn point.
	var sp := _SPAWN_CATALOG.player_spawn if _SPAWN_CATALOG != null else null
	var start_level: Enums.Levels = Enums.Levels.PLAYER_HOUSE
	if sp != null and sp.is_valid():
		start_level = sp.level_id as Enums.Levels

	var options := {}
	if sp != null and sp.is_valid():
		options["spawn_point"] = sp

	var ok: bool = await Runtime.scene_loader.load_level_and_hydrate(start_level, options)
	if not ok:
		return false

	# Initial Save
	if AgentBrain.registry != null:
		var a = AgentBrain.registry.save_to_session()
		if a != null:
			Runtime.save_manager.save_session_agents_save(a)

	var gs := GameSave.new()
	gs.active_level_id = start_level
	gs.current_day = 1
	gs.minute_of_day = 6 * 60
	Runtime.save_manager.save_session_game_save(gs)

	# Initial Quest save (empty).
	if QuestManager != null and Runtime.save_manager != null:
		var qs: QuestSave = QuestManager.capture_state()
		if qs != null:
			Runtime.save_manager.save_session_quest_save(qs)

	return true


func continue_session() -> bool:
	return await flow.run_loading_action(func() -> bool: return await _continue_session_inner())


func _continue_session_inner() -> bool:
	if Runtime == null or Runtime.save_manager == null or Runtime.scene_loader == null:
		return false

	var gs = Runtime.save_manager.load_session_game_save()
	if gs == null:
		return false

	if AgentBrain.registry != null:
		AgentBrain.registry.load_from_session(Runtime.save_manager.load_session_agents_save())

	if DialogueManager != null:
		var ds = Runtime.save_manager.load_session_dialogue_save()
		if ds != null:
			DialogueManager.hydrate_state(ds)

	if QuestManager != null and Runtime.save_manager != null:
		var qs: QuestSave = Runtime.save_manager.load_session_quest_save()
		if qs != null:
			QuestManager.hydrate_state(qs)
		else:
			QuestManager.reset_for_new_game()
	if DialogueManager != null:
		DialogueManager.sync_quest_state_from_manager()

	if TimeManager:
		TimeManager.current_day = int(gs.current_day)
		TimeManager.set_minute_of_day(int(gs.minute_of_day))

	var options = {"level_save": Runtime.save_manager.load_session_level_save(gs.active_level_id)}

	var ok: bool = await Runtime.scene_loader.load_level_and_hydrate(gs.active_level_id, options)
	if not ok:
		return false

	Runtime.autosave_session()
	return true
