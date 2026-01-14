extends GameState

const _SPAWN_CATALOG = preload("res://game/data/spawn_points/spawn_catalog.tres")


func enter(_prev: StringName = &"") -> void:
	# RUNNING gameplay state (single-state machine).
	if flow == null:
		return

	flow.force_unpaused()

	if UIManager != null:
		UIManager.hide_all_menus()
		UIManager.show(UIManager.ScreenName.HUD)
		# If quest notifications were queued during a modal flow (e.g. reward presentation),
		# flush them now (after menus were hidden) so they remain visible.
		if UIManager.has_method("flush_queued_quest_notifications"):
			UIManager.call("flush_queued_quest_notifications")

	GameplayUtils.set_player_input_enabled(flow.get_tree(), true)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), true)
	GameplayUtils.set_hotbar_visible(true)
	GameplayUtils.fade_vignette_out(0.15)


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	if check_player_menu_input(event):
		return GameStateNames.NONE

	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED

	# Debug/convenience: open Blacksmith menu.
	if event.is_action_pressed(&"open_blacksmith", false, true):
		if Runtime != null and Runtime.has_method("open_blacksmith"):
			Runtime.open_blacksmith()
		return GameStateNames.NONE

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

			# Autoloads persist across state changes; ensure a fully clean agent slate.
			if AgentBrain != null:
				AgentBrain.reset_for_new_game()
			if QuestManager != null:
				QuestManager.reset_for_new_game()
				QuestManager.start_unlocked_quests_on_new_game()

			Runtime.save_manager.reset_session()

			if AgentBrain.registry != null:
				AgentBrain.registry.load_from_session(
					Runtime.save_manager.load_session_agents_save()
				)

			if TimeManager:
				TimeManager.reset()
				# Default start time: 06:00
				TimeManager.set_minute_of_day(6 * 60)

			# New game starts at the configured player spawn point.
			var sp := _SPAWN_CATALOG.player_spawn if _SPAWN_CATALOG != null else null
			var start_level: Enums.Levels = Enums.Levels.PLAYER_HOUSE
			if sp != null and sp.is_valid():
				start_level = sp.level_id

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
				var qs := QuestManager.capture_state()
				if qs != null:
					Runtime.save_manager.save_session_quest_save(qs)

			# Initial Relationships save (empty).
			if RelationshipManager != null and Runtime.save_manager != null:
				var rs: RelationshipsSave = RelationshipManager.capture_state()
				if (
					rs != null
					and Runtime.save_manager.has_method("save_session_relationships_save")
				):
					Runtime.save_manager.save_session_relationships_save(rs)

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

			var options = {
				"level_save": Runtime.save_manager.load_session_level_save(gs.active_level_id)
			}

			var ok: bool = await Runtime.scene_loader.load_level_and_hydrate(
				gs.active_level_id, options
			)
			if not ok:
				return false

			# Post-load autosave is handled by GameFlow after the loading transaction ends.
			return true
	)
