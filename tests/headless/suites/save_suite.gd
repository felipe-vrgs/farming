extends RefCounted


func register(runner: Node) -> void:
	var sm = load("res://globals/game_flow/save/save_manager.gd").new()
	# Avoid contaminating real user saves: use a unique session id.
	var session_id := "test_session_%d" % int(Time.get_ticks_msec())
	runner.add_test(
		"save_manager_roundtrip",
		func() -> void:
			sm.call("set_session", session_id)
			sm.call("reset_session")

			var gs := GameSave.new()
			gs.active_level_id = Enums.Levels.ISLAND
			gs.current_day = 7
			gs.minute_of_day = 123

			runner._assert_true(
				sm.save_session_game_save(gs), "SaveManager should save session game.tres"
			)

			var gs2 = sm.load_session_game_save()
			runner._assert_true(gs2 != null, "SaveManager should load session game.tres")
			runner._assert_eq(int(gs2.current_day), 7, "GameSave roundtrip current_day")
			runner._assert_eq(int(gs2.minute_of_day), 123, "GameSave roundtrip minute_of_day")
			runner._assert_eq(
				int(gs2.active_level_id),
				int(Enums.Levels.ISLAND),
				"GameSave roundtrip active_level_id"
			)

			# Slot copy smoke.
			runner._assert_true(
				sm.copy_session_to_slot("test_slot"), "copy_session_to_slot should succeed"
			)
			runner._assert_true(
				sm.slot_exists("test_slot"), "slot_exists should be true after copy"
			)

			# Cleanup best-effort.
			sm.delete_slot("test_slot")
			sm.reset_session()
	)

	runner.add_test(
		"save_manager_level_save_roundtrip",
		func() -> void:
			sm.set_session(session_id)
			sm.reset_session()

			var ls := LevelSave.new()
			ls.level_id = Enums.Levels.FRIEREN_HOUSE

			var cs := CellSnapshot.new()
			cs.coords = Vector2i(5, 5)
			cs.terrain_id = 2
			ls.cells = [cs]

			runner._assert_true(sm.save_session_level_save(ls), "Should save level save")

			var ls2 = sm.load_session_level_save(Enums.Levels.FRIEREN_HOUSE)
			runner._assert_true(ls2 != null, "Should load level save")
			runner._assert_eq(
				int(ls2.level_id), int(Enums.Levels.FRIEREN_HOUSE), "Level ID should match"
			)
			runner._assert_eq(ls2.cells.size(), 1, "Cells count should match")
			runner._assert_eq(ls2.cells[0].coords, Vector2i(5, 5), "Cell coords should match")

			var ids = sm.list_session_level_ids()
			runner._assert_true(
				Enums.Levels.FRIEREN_HOUSE in ids, "Level ID should be in session level ids list"
			)

			sm.reset_session()
	)

	runner.add_test(
		"save_manager_agents_save_roundtrip",
		func() -> void:
			sm.set_session(session_id)
			sm.reset_session()

			var asave := AgentsSave.new()
			var rec := AgentRecord.new()
			rec.agent_id = &"test_agent"
			asave.agents = [rec]

			runner._assert_true(sm.save_session_agents_save(asave), "Should save agents save")

			var asave2 = sm.load_session_agents_save()
			runner._assert_true(asave2 != null, "Should load agents save")
			runner._assert_eq(asave2.agents.size(), 1, "Agents count should match")
			runner._assert_eq(
				String(asave2.agents[0].agent_id), "test_agent", "Agent ID should match"
			)

			sm.reset_session()
	)
