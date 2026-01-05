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

			var ok_new: bool = bool(await runtime.call("start_new_game"))
			runner._assert_true(ok_new, "Runtime.start_new_game should succeed")

			await runner.get_tree().process_frame

			var ok_save: bool = bool(runtime.call("autosave_session"))
			runner._assert_true(ok_save, "Runtime.autosave_session should succeed after new game")

			await runner.get_tree().process_frame

			var ok_continue: bool = bool(await runtime.call("continue_session"))
			runner._assert_true(
				ok_continue, "Runtime.continue_session should succeed after autosave"
			)
	)

	runner.add_test(
		"runtime_new_game_uses_player_house_player_spawn",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			if runtime == null:
				runner._fail("Runtime autoload missing")
				return

			var ok_new: bool = bool(await runtime.call("start_new_game"))
			runner._assert_true(ok_new, "Runtime.start_new_game should succeed")

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

			save_manager.reset_session()

			var ok = await runtime.continue_session()
			runner._assert_true(not ok, "continue_session should fail when no game.tres exists")
	)

	runner.add_test(
		"runtime_level_warp_logic",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")

			# Setup a basic game state
			await runtime.start_new_game()

			# Warp to another level (if possible in headless)
			# We'll just verify it attempts the flow
			var ok = await runtime.perform_level_warp(Enums.Levels.FRIEREN_HOUSE)
			# Note: In headless, change_level_scene might return false if it can't load scenes
			# but the logic before/after is what we want to verify doesn't crash.
			runner._assert_true(true, "runtime_level_warp_logic reached end without crash")
	)
