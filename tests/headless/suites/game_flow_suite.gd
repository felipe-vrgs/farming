extends RefCounted

## Regression tests for GameFlow state transitions (headless-safe).
## Note: Headless runs set FARMING_TEST_MODE=1, so GameFlow doesn't auto-boot into MENU.
## These tests explicitly drive state via public methods.

const STATE_IN_GAME := &"in_game"
const STATE_PLAYER_MENU := &"player_menu"
const STATE_DIALOGUE := &"dialogue"
const STATE_CUTSCENE := &"cutscene"


func register(runner: Node) -> void:
	runner.add_test(
		"game_flow_player_menu_toggle_restores_input",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			if runtime == null:
				runner._fail("Runtime autoload missing")
				return

			var gf: Node = runtime.get("game_flow") as Node
			runner._assert_true(gf != null, "Runtime.game_flow missing")
			if gf == null:
				return

			# Ensure we are in MENU state to allow start_new_game.
			gf.call("return_to_main_menu")
			await runner.get_tree().process_frame

			# Ensure we have a player instance.
			var ok_new: bool = bool(await gf.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")

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
				StringName(gf.get("state")),
				StringName(STATE_PLAYER_MENU),
				"State should enter PLAYER_MENU"
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
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_IN_GAME),
				"State should return to IN_GAME"
			)
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

			var gf: Node = runtime.get("game_flow") as Node
			runner._assert_true(gf != null, "Runtime.game_flow missing")
			if gf == null:
				return

			var ok_new: bool = bool(await gf.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")

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
				StringName(gf.get("state")),
				StringName(STATE_PLAYER_MENU),
				"Input should open PLAYER_MENU"
			)
			(
				runner
				. _assert_true(
					not bool(player.input_enabled),
					"Player input disabled after opening via input",
				)
			)

			# Close via Tab toggle action.
			gf.call("_unhandled_input", ev)
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_IN_GAME),
				"Input should close back to IN_GAME"
			)
			(
				runner
				. _assert_true(
					bool(player.input_enabled),
					"Player input re-enabled after closing via input",
				)
			)
	)

	runner.add_test(
		"game_flow_player_menu_inventory_action_toggles_when_on_inventory_tab",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			runner._assert_true(runtime != null, "Runtime autoload missing")
			if runtime == null:
				return

			var gf: Node = runtime.get("game_flow") as Node
			runner._assert_true(gf != null, "Runtime.game_flow missing")
			if gf == null:
				return

			var ok_new: bool = bool(await gf.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")
			if gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			# Open inventory tab via action.
			var ev := InputEventAction.new()
			ev.action = &"open_player_menu_inventory"
			ev.pressed = true
			gf.call("_unhandled_input", ev)
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_PLAYER_MENU),
				"Inventory action should open PLAYER_MENU"
			)

			# Pressing again while already on inventory tab should close.
			gf.call("_unhandled_input", ev)
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_IN_GAME),
				"Inventory action should close PLAYER_MENU when already on inventory tab"
			)
	)

	runner.add_test(
		"game_flow_player_menu_quests_action_toggles_when_on_quests_tab",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			runner._assert_true(runtime != null, "Runtime autoload missing")
			if runtime == null:
				return

			var gf: Node = runtime.get("game_flow") as Node
			runner._assert_true(gf != null, "Runtime.game_flow missing")
			if gf == null:
				return

			var ok_new: bool = bool(await gf.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")
			if gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			# Open quests tab via action.
			var ev := InputEventAction.new()
			ev.action = &"open_player_menu_quests"
			ev.pressed = true
			gf.call("_unhandled_input", ev)
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_PLAYER_MENU),
				"Quests action should open PLAYER_MENU"
			)

			# Pressing again while already on quests tab should close.
			gf.call("_unhandled_input", ev)
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_IN_GAME),
				"Quests action should close PLAYER_MENU when already on quests tab"
			)
	)

	runner.add_test(
		"game_flow_pause_from_dialogue_or_cutscene_preserves_world_mode_and_blocks_saves",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			runner._assert_true(runtime != null, "Runtime autoload missing")
			if runtime == null:
				return

			var gf: Node = runtime.get("game_flow") as Node
			runner._assert_true(gf != null, "Runtime.game_flow missing")
			if gf == null:
				return

			# Ensure we have a running gameplay scene.
			gf.call("return_to_main_menu")
			await runner.get_tree().process_frame
			var ok_new: bool = bool(await gf.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")
			if gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			# Helper to "press pause" through GameFlow's input handler.
			var press_pause := func() -> void:
				var ev := InputEventAction.new()
				ev.action = &"pause"
				ev.pressed = true
				gf.call("_unhandled_input", ev)

			# ---- Dialogue: pause should keep world-mode = DIALOGUE and block autosave.
			gf.call("request_flow_state", Enums.FlowState.DIALOGUE)
			await runner.get_tree().process_frame
			press_pause.call()
			await runner.get_tree().process_frame

			(
				runner
				. _assert_eq(
					int(runtime.flow_state),
					int(Enums.FlowState.DIALOGUE),
					"Pausing from DIALOGUE should preserve world-mode as DIALOGUE",
				)
			)
			var ok_save_dialogue: bool = bool(runtime.call("autosave_session"))
			(
				runner
				. _assert_true(
					not ok_save_dialogue,
					"autosave_session should be blocked while paused-from dialogue",
				)
			)

			# Unpause back to dialogue, then return to running.
			press_pause.call()
			await runner.get_tree().process_frame
			gf.call("request_flow_state", Enums.FlowState.RUNNING)
			await runner.get_tree().process_frame

			# ---- Cutscene: pause should keep world-mode = CUTSCENE and block autosave.
			gf.call("request_flow_state", Enums.FlowState.CUTSCENE)
			await runner.get_tree().process_frame
			press_pause.call()
			await runner.get_tree().process_frame

			(
				runner
				. _assert_eq(
					int(runtime.flow_state),
					int(Enums.FlowState.CUTSCENE),
					"Pausing from CUTSCENE should preserve world-mode as CUTSCENE",
				)
			)
			var ok_save_cutscene: bool = bool(runtime.call("autosave_session"))
			(
				runner
				. _assert_true(
					not ok_save_cutscene,
					"autosave_session should be blocked while paused-from cutscene",
				)
			)

			# Cleanup.
			press_pause.call()
			await runner.get_tree().process_frame
			gf.call("request_flow_state", Enums.FlowState.RUNNING)
			await runner.get_tree().process_frame
	)

	runner.add_test(
		"game_flow_quit_to_menu_during_dialogue_does_not_persist_dialogue_variables",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			runner._assert_true(runtime != null, "Runtime autoload missing")
			if runtime == null:
				return

			var gf: Node = runtime.get("game_flow") as Node
			runner._assert_true(gf != null, "Runtime.game_flow missing")
			if gf == null:
				return

			var dm: Node = runner._get_autoload(&"DialogueManager")
			runner._assert_true(dm != null, "DialogueManager autoload missing")
			if dm == null:
				return

			# Ensure a baseline session save exists (including dialogue save).
			gf.call("return_to_main_menu")
			await runner.get_tree().process_frame
			var ok_new: bool = bool(await gf.call("start_new_game"))
			runner._assert_true(ok_new, "start_new_game should succeed")
			if gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			var ok_base: bool = bool(runtime.call("autosave_session"))
			runner._assert_true(ok_base, "Precondition: autosave_session should succeed in RUNNING")

			# Load baseline dialogue save from disk.
			var sm: Node = runtime.get("save_manager") as Node
			runner._assert_true(sm != null, "Runtime.save_manager missing")
			if sm == null:
				return
			var base_ds: DialogueSave = sm.call("load_session_dialogue_save") as DialogueSave
			runner._assert_true(
				base_ds != null, "Baseline DialogueSave should exist after autosave"
			)
			if base_ds == null:
				return

			# Mutate in-memory Dialogic variables to simulate "dialogue started" flags,
			# and mark the dialogue manager as active.
			var facade: Node = dm.get("facade") as Node
			runner._assert_true(facade != null, "DialogueManager.facade missing")
			if facade == null:
				return

			var vars_any: Variant = facade.call("get_variables")
			var vars: Dictionary = vars_any if vars_any is Dictionary else {}
			vars["__test_dialogue_started"] = true
			facade.call("set_variables", vars)
			dm.set("_active", true)

			# Quit to menu while "dialogue is active". MenuState.enter() used to autosave first,
			# which would persist the mutated variables; this must be blocked now.
			gf.call("quit_to_menu")
			await runner.get_tree().process_frame

			var ds_after: DialogueSave = sm.call("load_session_dialogue_save") as DialogueSave
			runner._assert_true(
				ds_after != null, "DialogueSave should still be readable after quit_to_menu"
			)
			if ds_after == null:
				return

			var d_after: Dictionary = ds_after.dialogic_variables
			(
				runner
				. _assert_true(
					not d_after.has("__test_dialogue_started"),
					"Quit-to-menu during dialogue should NOT persist in-progress dialogue variables",
				)
			)
	)

	runner.add_test(
		"game_flow_dialogue_cutscene_force_close_overlays",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			if runtime == null:
				runner._fail("Runtime autoload missing")
				return

			var gf: Node = runtime.get("game_flow") as Node
			runner._assert_true(gf != null, "Runtime.game_flow missing")
			if gf == null:
				return

			var ok_new: bool = bool(await gf.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")

			if gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			var ui = runner._get_autoload(&"UIManager")
			runner._assert_true(ui != null, "UIManager autoload missing")
			if ui == null:
				return

			# Open player menu first.
			gf.call("toggle_player_menu")
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_PLAYER_MENU),
				"Precondition: in PLAYER_MENU"
			)

			# Enter dialogue: should force-close overlays and pause tree.
			gf.call("request_flow_state", Enums.FlowState.DIALOGUE)
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_DIALOGUE),
				"Should enter DIALOGUE state"
			)
			var pm = ui.call("get_screen_node", ui.ScreenName.PLAYER_MENU)
			if pm != null:
				runner._assert_true(
					not bool(pm.visible), "Player menu should be hidden in DIALOGUE"
				)
			runner._assert_true(runner.get_tree().paused, "SceneTree should be paused in DIALOGUE")

			# Return to running.
			gf.call("request_flow_state", Enums.FlowState.RUNNING)
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_IN_GAME),
				"Should return to IN_GAME from DIALOGUE"
			)

			# Enter cutscene from player menu: should force-close overlays and keep tree unpaused.
			gf.call("toggle_player_menu")
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_PLAYER_MENU),
				"Precondition: in PLAYER_MENU again"
			)

			gf.call("request_flow_state", Enums.FlowState.CUTSCENE)
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")),
				StringName(STATE_CUTSCENE),
				"Should enter CUTSCENE state"
			)
			pm = ui.call("get_screen_node", ui.ScreenName.PLAYER_MENU)
			if pm != null:
				runner._assert_true(
					not bool(pm.visible), "Player menu should be hidden in CUTSCENE"
				)
			runner._assert_true(
				not runner.get_tree().paused, "SceneTree should NOT be paused in CUTSCENE"
			)

			# Restore baseline for subsequent suites.
			gf.call("request_flow_state", Enums.FlowState.RUNNING)
			await runner.get_tree().process_frame
			runner._assert_eq(
				StringName(gf.get("state")), StringName(STATE_IN_GAME), "Cleanup: return to IN_GAME"
			)
	)

	runner.add_test(
		"quest_panel_clicking_completed_then_active_updates_selection",
		func() -> void:
			# Regression for: selecting a completed quest could make the details panel feel
			# "stuck" because the previously-selected active quest would not re-emit
			# `item_selected` when clicked again.
			var scene := load("res://game/ui/player_menu/quest/quest_panel.tscn") as PackedScene
			runner._assert_true(scene != null, "QuestPanel scene should load")
			if scene == null:
				return

			var qp := scene.instantiate()
			runner._assert_true(qp != null, "QuestPanel scene should instantiate")
			if qp == null:
				return

			runner.get_tree().root.add_child(qp)
			await runner.get_tree().process_frame

			var active_list := qp.get_node_or_null("Content/Lists/ActiveList") as ItemList
			var completed_list := qp.get_node_or_null("Content/Lists/CompletedList") as ItemList
			runner._assert_true(active_list != null, "QuestPanel.ActiveList missing")
			runner._assert_true(completed_list != null, "QuestPanel.CompletedList missing")
			if active_list == null or completed_list == null:
				qp.queue_free()
				return

			# Bypass QuestManager state: we only care about selection mechanics + handler effects.
			qp.set("_active_ids", [&"q_active"])
			qp.set("_completed_ids", [&"q_done"])
			qp.call("_refresh_lists_from_ids")
			await runner.get_tree().process_frame

			# Ensure the lists were populated as expected.
			runner._assert_eq(active_list.item_count, 1, "Active list should contain 1 item")
			runner._assert_eq(completed_list.item_count, 1, "Completed list should contain 1 item")
			if active_list.item_count < 1 or completed_list.item_count < 1:
				qp.queue_free()
				return

			# Precondition: panel auto-selects first active quest.
			runner._assert_true(
				not active_list.get_selected_items().is_empty(),
				"Precondition: active quest should be selected"
			)
			runner._assert_true(
				completed_list.get_selected_items().is_empty(),
				"Precondition: completed quest should not be selected"
			)
			runner._assert_true(
				bool(qp.get("_current_is_active")), "Precondition: showing active quest"
			)

			# Select completed quest: should clear active selection.
			completed_list.select(0)
			await runner.get_tree().process_frame
			runner._assert_true(
				active_list.get_selected_items().is_empty(),
				"Selecting completed should deselect active list"
			)
			runner._assert_true(
				not bool(qp.get("_current_is_active")),
				"After selecting completed, current quest should be marked not-active"
			)

			# Select active quest again: must work even if it was the only item.
			active_list.select(0)
			await runner.get_tree().process_frame
			runner._assert_true(
				completed_list.get_selected_items().is_empty(),
				"Selecting active should deselect completed list"
			)
			runner._assert_true(
				bool(qp.get("_current_is_active")),
				"After selecting active, current quest should be marked active"
			)

			qp.queue_free()
			await runner.get_tree().process_frame
	)
