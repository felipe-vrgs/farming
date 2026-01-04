extends RefCounted

func register(runner) -> void:
	runner.add_test("runtime_smoke_new_game_save_continue", func() -> void:
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
		runner._assert_true(ok_continue, "Runtime.continue_session should succeed after autosave")
	)
