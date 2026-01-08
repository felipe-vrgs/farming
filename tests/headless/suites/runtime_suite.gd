extends RefCounted


func register(runner: Node) -> void:
	runner.add_test(
		"runtime_smoke_new_game_save_continue",
		func() -> void:
			# Thin integration smoke test: catches regressions in load/bind/save plumbing.
			var runtime = runner._get_autoload(&"Runtime")
			if runtime == null:
				runner._fail("Runtime autoload missing")
				return

			if (
				"game_flow" in runtime
				and runtime.get("game_flow") == null
				and runtime.has_method("_ensure_dependencies")
			):
				runtime.call("_ensure_dependencies")

			var flow = runtime.get("game_flow")
			if flow == null:
				runner._fail("GameFlow missing")
				return

			# Ensure we are in MENU state.
			flow.call("return_to_main_menu")
			await runner.get_tree().process_frame

			var ok_new: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")

			await runner.get_tree().process_frame

			# Preconditions for autosave: helps pinpoint regressions if autosave returns false.
			(
				runner
				. _assert_eq(
					int(runtime.flow_state),
					int(Enums.FlowState.RUNNING),
					"Runtime.flow_state should be RUNNING after new game",
				)
			)
			var lr := runtime.call("get_active_level_root") as LevelRoot
			runner._assert_true(lr != null, "Active LevelRoot should exist after new game")
			runner._assert_true(WorldGrid != null, "WorldGrid autoload missing")
			if lr != null and WorldGrid != null:
				var ls := LevelCapture.capture(lr, WorldGrid)
				runner._assert_true(
					ls != null, "LevelCapture.capture should succeed after new game"
				)

			var ok_save: bool = bool(runtime.call("autosave_session"))
			runner._assert_true(ok_save, "Runtime.autosave_session should succeed after new game")

			await runner.get_tree().process_frame

			var ok_continue: bool = bool(await flow.call("continue_session"))
			runner._assert_true(
				ok_continue, "GameFlow.continue_session should succeed after autosave"
			)
	)

	runner.add_test(
		"runtime_new_game_uses_player_spawn_resource",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			if runtime == null:
				runner._fail("Runtime autoload missing")
				return

			var flow = runtime.get("game_flow")
			var ok_new: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")

			# Allow one frame for AgentSpawner to seed and capture the player record.
			await runner.get_tree().process_frame

			var sp_path := "res://game/data/spawn_points/player_spawn.tres"
			runner._assert_true(
				ResourceLoader.exists(sp_path),
				"Missing SpawnPointData resource for tests: player_spawn.tres"
			)
			var sp := load(sp_path) as SpawnPointData
			runner._assert_true(
				sp != null and sp.is_valid(), "player_spawn.tres should load and be valid"
			)

			var agent_brain = runner._get_autoload(&"AgentBrain")
			runner._assert_true(agent_brain != null, "AgentBrain autoload missing")
			var reg: AgentRegistry = agent_brain.get("registry") as AgentRegistry
			runner._assert_true(reg != null, "AgentBrain.registry missing")

			var rec := reg.get_record(&"player") as AgentRecord
			runner._assert_true(rec != null, "Player AgentRecord should exist after start_new_game")
			runner._assert_eq(
				int(rec.current_level_id),
				int(sp.level_id),
				"New game should start with player record in player_spawn's level"
			)
			runner._assert_eq(
				rec.last_world_pos,
				sp.position,
				"New game player spawn position should match player_spawn.tres"
			)
	)

	runner.add_test(
		"runtime_continue_no_save_fails",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			var save_manager = runtime.get("save_manager")
			var flow = runtime.get("game_flow")

			save_manager.reset_session()

			var ok = await flow.continue_session()
			runner._assert_true(not ok, "continue_session should fail when no game.tres exists")
	)

	runner.add_test(
		"runtime_level_change_logic",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			var flow = runtime.get("game_flow")

			await flow.call("start_new_game")
			await runner.get_tree().process_frame

			# Change level (to Island)
			await flow.call("_on_level_change_requested", Enums.Levels.ISLAND, null)
			await runner.get_tree().process_frame

			var current = runtime.call("get_active_level_id")
			runner._assert_eq(current, Enums.Levels.ISLAND, "Should change to Island")
	)

	runner.add_test(
		"runtime_new_game_resets_npc_records_and_does_not_leak",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			if runtime == null:
				runner._fail("Runtime autoload missing")
				return
			var flow = runtime.get("game_flow")
			if flow == null:
				runner._fail("GameFlow missing")
				return

			var ok_new: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new, "start_new_game should succeed (setup)")
			await runner.get_tree().process_frame

			var agent_brain = runner._get_autoload(&"AgentBrain")
			runner._assert_true(agent_brain != null, "AgentBrain autoload missing")
			var reg: AgentRegistry = agent_brain.get("registry") as AgentRegistry
			runner._assert_true(reg != null, "AgentBrain.registry missing")

			# Simulate an old/stale session where Frieren was in PLAYER_HOUSE.
			var frieren := reg.get_record(&"frieren") as AgentRecord
			runner._assert_true(frieren != null, "Frieren AgentRecord should exist after new game")
			frieren.current_level_id = Enums.Levels.PLAYER_HOUSE
			frieren.last_spawn_point_path = ""
			frieren.needs_spawn_marker = false
			frieren.last_cell = Vector2i(0, 0)
			frieren.last_world_pos = Vector2(123, 456)
			reg.upsert_record(frieren)

			# Persist to session (so if new game doesn't reset session, it will leak).
			var a := reg.save_to_session()
			runner._assert_true(a != null, "AgentsSave should serialize")
			(
				runner
				. _assert_true(
					runtime.save_manager.save_session_agents_save(a),
					"save_session_agents_save should succeed",
				)
			)

			# Start a fresh new game; Frieren should be reset to her initial spawn point (Frieren House).
			var ok_new2: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new2, "start_new_game should succeed (reset)")
			await runner.get_tree().process_frame

			var frieren2 := reg.get_record(&"frieren") as AgentRecord
			runner._assert_true(frieren2 != null, "Frieren AgentRecord should exist after reset")
			(
				runner
				. _assert_eq(
					int(frieren2.current_level_id),
					int(Enums.Levels.FRIEREN_HOUSE),
					"New game should reset Frieren to initial spawn level (FRIEREN_HOUSE)",
				)
			)
	)

	runner.add_test(
		"runtime_continue_ignores_zero_origin_player_record",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			if runtime == null:
				runner._fail("Runtime autoload missing")
				return
			var flow = runtime.get("game_flow")
			if flow == null:
				runner._fail("GameFlow missing")
				return

			var ok_new: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new, "start_new_game should succeed")
			await runner.get_tree().process_frame

			# Force a corrupted player record (0,0), then verify continue uses spawn point.
			var agent_brain = runner._get_autoload(&"AgentBrain")
			runner._assert_true(agent_brain != null, "AgentBrain autoload missing")
			var reg: AgentRegistry = agent_brain.get("registry") as AgentRegistry
			runner._assert_true(reg != null, "AgentBrain.registry missing")

			var p := reg.get_record(&"player") as AgentRecord
			runner._assert_true(p != null, "Player AgentRecord missing")
			p.last_world_pos = Vector2.ZERO
			p.last_cell = Vector2i(0, 0)
			p.last_spawn_point_path = ""
			p.needs_spawn_marker = false
			reg.upsert_record(p)

			var a := reg.save_to_session()
			runner._assert_true(a != null, "AgentsSave should serialize")
			(
				runner
				. _assert_true(
					runtime.save_manager.save_session_agents_save(a),
					"save_session_agents_save should succeed",
				)
			)

			# Ensure a game save exists for continue.
			var sp_path := "res://game/data/spawn_points/player_spawn.tres"
			var sp := load(sp_path) as SpawnPointData
			runner._assert_true(
				sp != null and sp.is_valid(), "player_spawn.tres should load and be valid"
			)

			var gs: GameSave = runtime.save_manager.load_session_game_save()
			if gs == null:
				gs = GameSave.new()
			gs.active_level_id = sp.level_id
			gs.current_day = 1
			gs.minute_of_day = 6 * 60
			runtime.save_manager.save_session_game_save(gs)

			var ok_continue: bool = bool(await flow.call("continue_session"))
			runner._assert_true(ok_continue, "continue_session should succeed")
			await runner.get_tree().process_frame

			var p2 := reg.get_record(&"player") as AgentRecord
			runner._assert_true(p2 != null, "Player AgentRecord missing after continue")
			(
				runner
				. _assert_true(
					p2.last_world_pos != Vector2.ZERO,
					"Player should not remain at (0,0) after continue",
				)
			)
	)
