extends RefCounted


func register(runner: Node) -> void:
	runner.add_test(
		"relationships_manager_capture_hydrate_clamp",
		func() -> void:
			runner._assert_true(
				RelationshipManager != null, "RelationshipManager autoload should exist"
			)
			RelationshipManager.reset_for_new_game()

			# Create synthetic ids (should be allowed even if not in configs).
			RelationshipManager.set_units(&"test_npc", 999)
			runner._assert_eq(
				int(RelationshipManager.get_units(&"test_npc")), 20, "Units should clamp to 20"
			)
			RelationshipManager.add_units(&"test_npc", -999)
			runner._assert_eq(
				int(RelationshipManager.get_units(&"test_npc")), 0, "Units should clamp to 0"
			)

			RelationshipManager.set_units(&"test_npc", 7)
			var save: RelationshipsSave = RelationshipManager.capture_state()
			runner._assert_true(save != null, "capture_state should return a save resource")

			RelationshipManager.reset_for_new_game()
			runner._assert_eq(
				int(RelationshipManager.get_units(&"test_npc")),
				0,
				"reset should clear test_npc value"
			)

			RelationshipManager.hydrate_state(save)
			runner._assert_eq(
				int(RelationshipManager.get_units(&"test_npc")), 7, "hydrate should restore values"
			)
	)

	runner.add_test(
		"relationships_save_manager_roundtrip",
		func() -> void:
			var sm = load("res://game/globals/game_flow/save/save_manager.gd").new()
			var session_id := "test_session_%d" % int(Time.get_ticks_msec())
			sm.call("set_session", session_id)
			sm.call("reset_session")

			var rs := RelationshipsSave.new()
			rs.values = {"frieren": 3, "shiryu": 11, "bad": 999}
			runner._assert_true(
				sm.save_session_relationships_save(rs), "Should save relationships.tres"
			)

			var rs2: RelationshipsSave = sm.load_session_relationships_save()
			runner._assert_true(rs2 != null, "Should load relationships.tres")
			runner._assert_eq(
				int((rs2.values as Dictionary).get("frieren", -1)),
				3,
				"RelationshipsSave roundtrip value"
			)
			runner._assert_eq(
				int((rs2.values as Dictionary).get("shiryu", -1)),
				11,
				"RelationshipsSave roundtrip value 2"
			)

			sm.call("reset_session")
	)
