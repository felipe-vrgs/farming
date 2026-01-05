extends RefCounted

## Regression tests for GameFlow state transitions (headless-safe).
## Note: Headless runs set FARMING_TEST_MODE=1, so GameFlow doesn't auto-boot into MENU.
## These tests explicitly drive state via public methods.

const STATE_IN_GAME := 3
const STATE_PLAYER_MENU := 5


func register(runner: Node) -> void:
	runner.add_test(
		"game_flow_player_menu_toggle_restores_input",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			if runtime == null:
				runner._fail("Runtime autoload missing")
				return

			# Ensure we have a player instance.
			var ok_new: bool = bool(await runtime.call("start_new_game"))
			runner._assert_true(ok_new, "Runtime.start_new_game should succeed")

			var gf: Node = runtime.get("game_flow") as Node
			runner._assert_true(gf != null, "Runtime.game_flow missing")
			if gf == null:
				return

			# In test mode, GameFlow doesn't boot; explicitly enter gameplay.
			if gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			var player := runner.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			runner._assert_true(player != null, "Player should exist after start_new_game")
			if player == null:
				return

			runner._assert_true(bool(player.input_enabled), "Player input should start enabled")

			# Open menu
			runner._assert_true(
				gf.has_method("toggle_player_menu"), "GameFlow.toggle_player_menu missing"
			)
			gf.call("toggle_player_menu")
			await runner.get_tree().process_frame
			runner._assert_eq(
				int(gf.get("state")), STATE_PLAYER_MENU, "State should enter PLAYER_MENU"
			)
			(
				runner
				. _assert_true(
					not bool(player.input_enabled),
					"Player input should be disabled in PLAYER_MENU",
				)
			)

			# Close menu
			gf.call("toggle_player_menu")
			await runner.get_tree().process_frame
			runner._assert_eq(int(gf.get("state")), STATE_IN_GAME, "State should return to IN_GAME")
			(
				runner
				. _assert_true(
					bool(player.input_enabled),
					"Player input should be re-enabled after closing menu",
				)
			)
	)

	runner.add_test(
		"game_flow_player_menu_input_event_toggles",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			if runtime == null:
				runner._fail("Runtime autoload missing")
				return

			var ok_new: bool = bool(await runtime.call("start_new_game"))
			runner._assert_true(ok_new, "Runtime.start_new_game should succeed")

			var gf: Node = runtime.get("game_flow") as Node
			runner._assert_true(gf != null, "Runtime.game_flow missing")
			if gf == null:
				return

			if gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			var player := runner.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			runner._assert_true(player != null, "Player should exist after start_new_game")
			if player == null:
				return

			# Simulate the action event being handled by GameFlow directly.
			var ev := InputEventAction.new()
			ev.action = &"open_player_menu"
			ev.pressed = true

			gf.call("_unhandled_input", ev)
			await runner.get_tree().process_frame
			runner._assert_eq(
				int(gf.get("state")), STATE_PLAYER_MENU, "Input should open PLAYER_MENU"
			)
			(
				runner
				. _assert_true(
					not bool(player.input_enabled),
					"Player input disabled after opening via input",
				)
			)

			gf.call("_unhandled_input", ev)
			await runner.get_tree().process_frame
			runner._assert_eq(
				int(gf.get("state")), STATE_IN_GAME, "Input should close back to IN_GAME"
			)
			(
				runner
				. _assert_true(
					bool(player.input_enabled),
					"Player input re-enabled after closing via input",
				)
			)
	)
