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
		"runtime_new_game_uses_player_house_player_spawn",
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

			var sp_path := "res://game/data/spawn_points/player_house/player_spawn.tres"
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
				int(Enums.Levels.PLAYER_HOUSE),
				"New game should start with player record in PLAYER_HOUSE"
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
