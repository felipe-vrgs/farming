extends GameState


func enter(_prev: StringName = &"") -> void:
	# RUNNING gameplay state (single-state machine).
	if flow == null:
		return

	flow.force_unpaused()

	if UIManager != null:
		UIManager.hide_all_menus()
		UIManager.show(UIManager.ScreenName.HUD)

	GameplayUtils.set_player_input_enabled(flow.get_tree(), true)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), true)
	GameplayUtils.set_hotbar_visible(true)
	GameplayUtils.fade_vignette_out(0.15)


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	# Player menu toggle: only while actively playing.
	if event.is_action_pressed(&"open_player_menu"):
		if flow.get_player() != null:
			return GameStateNames.PLAYER_MENU

	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED

	return GameStateNames.NONE


func perform_level_change(
	target_level_id: Enums.Levels, fallback_spawn_point: SpawnPointData = null
) -> bool:
	if flow == null:
		return false

	# Preserve dialogue state during travel (e.g. if a cutscene triggered the travel).
	return await flow.run_loading_action(
		func() -> bool:
			if Runtime != null:
				Runtime.autosave_session()

			var options := {"spawn_point": fallback_spawn_point}
			# Pre-fetch level save if available
			if Runtime != null and Runtime.save_manager != null:
				options["level_save"] = Runtime.save_manager.load_session_level_save(
					target_level_id
				)

			if Runtime == null or Runtime.scene_loader == null:
				return false

			var ok: bool = await Runtime.scene_loader.load_level_and_hydrate(
				target_level_id, options
			)
			if not ok:
				return false

			# Update GameSave
			if Runtime.save_manager != null:
				var gs = Runtime.save_manager.load_session_game_save()
				if gs == null:
					gs = GameSave.new()
				gs.active_level_id = target_level_id
				if TimeManager:
					gs.current_day = int(TimeManager.current_day)
					gs.minute_of_day = int(TimeManager.get_minute_of_day())
				Runtime.save_manager.save_session_game_save(gs)

			return true,
		true  # preserve_dialogue_state
	)


func start_new_game() -> bool:
	return await flow.run_loading_action(
		func() -> bool:
			if Runtime.save_manager == null:
				return false

			Runtime.save_manager.reset_session()

			if AgentBrain.registry != null:
				AgentBrain.registry.load_from_session(
					Runtime.save_manager.load_session_agents_save()
				)

			if TimeManager:
				TimeManager.reset()
				# Default start time: 06:00
				TimeManager.set_minute_of_day(6 * 60)

			# New game starts at Player House
			var start_level := Enums.Levels.PLAYER_HOUSE
			var ok: bool = await Runtime.scene_loader.load_level_and_hydrate(start_level)
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

			return true
	)


func continue_session() -> bool:
	return await flow.run_loading_action(
		func() -> bool:
			if Runtime.save_manager == null:
				return false

			var gs = Runtime.save_manager.load_session_game_save()
			if gs == null:
				return false

			if AgentBrain.registry != null:
				AgentBrain.registry.load_from_session(
					Runtime.save_manager.load_session_agents_save()
				)

			if DialogueManager != null:
				var ds = Runtime.save_manager.load_session_dialogue_save()
				if ds != null:
					DialogueManager.hydrate_state(ds)

			if TimeManager:
				TimeManager.current_day = int(gs.current_day)
				TimeManager.set_minute_of_day(int(gs.minute_of_day))

			var options = {
				"level_save": Runtime.save_manager.load_session_level_save(gs.active_level_id)
			}

			var ok: bool = await Runtime.scene_loader.load_level_and_hydrate(
				gs.active_level_id, options
			)
			if not ok:
				return false

			Runtime.autosave_session()
			return true
	)
