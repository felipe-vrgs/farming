extends RefCounted

## Regression tests for DialogueManager lifecycle and chaining.
## These tests are intentionally lightweight and use tiny timelines that end immediately.

const _MAX_WAIT_FRAMES := 90
const _MOVE_TWEEN_META_KEY := &"dialogic_additions_cutscene_move_tweens"


static func _wait_for(
	runner: Node, predicate: Callable, max_frames: int = _MAX_WAIT_FRAMES
) -> bool:
	for _i in range(max_frames):
		if bool(predicate.call()):
			return true
		await runner.get_tree().process_frame
	return false


func register(runner: Node) -> void:
	runner.add_test(
		"dialogue_manager_turns_actors_via_cutscene_actor_component",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			var dm: Node = runner._get_autoload(&"DialogueManager")
			runner._assert_true(runtime != null, "Runtime autoload missing")
			runner._assert_true(dm != null, "DialogueManager autoload missing")
			if runtime == null or dm == null:
				return

			var flow = runtime.get("game_flow")
			if flow == null:
				runner._fail("GameFlow missing")
				return

			flow.call("return_to_main_menu")
			await runner.get_tree().process_frame

			var ok_new: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")
			var gf: Node = runtime.get("game_flow") as Node
			if gf != null and gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			var player := runner.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			runner._assert_true(player != null, "Player should exist after start_new_game")
			if player == null:
				return

			# Spawn a temporary NPC and place it to the right of the player.
			var npc_scene := load("res://game/entities/npc/npc.tscn")
			runner._assert_true(npc_scene != null, "Failed to load npc.tscn")
			if npc_scene == null:
				return

			var npc = npc_scene.instantiate()
			runner.get_tree().current_scene.add_child(npc)
			await runner.get_tree().process_frame

			runner._assert_true(npc is NPC, "npc.tscn should instantiate an NPC")
			if not (npc is NPC):
				npc.queue_free()
				return

			(npc as Node2D).global_position = player.global_position + Vector2(20, 0)
			await runner.get_tree().process_frame

			# NPC should face left (toward player); player should face right (toward npc).
			dm.call("_turn_npc_toward_player", npc)
			dm.call("_turn_player_toward_npc", npc)
			await runner.get_tree().process_frame

			runner._assert_eq(
				(npc as NPC).facing_dir,
				Vector2.LEFT,
				"NPC should face toward player after dialogue-facing"
			)
			runner._assert_eq(
				player.raycell_component.facing_dir,
				Vector2.RIGHT,
				"Player should face toward NPC after dialogue-facing"
			)

			npc.queue_free()
	)

	runner.add_test(
		"cutscene_actor_component_move_to_registers_tween_meta_and_clears",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			var flow = runtime.get("game_flow") if runtime != null else null
			runner._assert_true(runtime != null, "Runtime autoload missing")
			runner._assert_true(flow != null, "GameFlow missing")
			if runtime == null or flow == null:
				return

			flow.call("return_to_main_menu")
			await runner.get_tree().process_frame

			var ok_new: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")
			var gf: Node = runtime.get("game_flow") as Node
			if gf != null and gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			var player := runner.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			runner._assert_true(player != null, "Player should exist after start_new_game")
			if player == null:
				return

			var comp_any := ComponentFinder.find_component_in_group(
				player, &"cutscene_actor_components"
			)
			runner._assert_true(
				comp_any is CutsceneActorComponent, "Player missing CutsceneActorComponent"
			)
			if not (comp_any is CutsceneActorComponent):
				return
			var comp := comp_any as CutsceneActorComponent

			var loop := Engine.get_main_loop()
			runner._assert_true(loop != null, "Engine main loop missing")
			if loop == null:
				return
			# Clear registry for deterministic results.
			if loop.has_meta(_MOVE_TWEEN_META_KEY):
				loop.set_meta(_MOVE_TWEEN_META_KEY, {})

			var target := player.global_position + Vector2(10, 0)
			var tw := comp.move_to(target, 100.0, &"player", Vector2.RIGHT)
			runner._assert_true(tw is Tween, "move_to should return a Tween")
			if not (tw is Tween):
				return

			# Should be registered under the same meta key used by cutscene_wait_for_moves.
			runner._assert_true(loop.has_meta(_MOVE_TWEEN_META_KEY), "Tween registry meta missing")
			var m_any = loop.get_meta(_MOVE_TWEEN_META_KEY)
			runner._assert_true(m_any is Dictionary, "Tween registry meta should be Dictionary")
			if m_any is Dictionary:
				runner._assert_true(
					(m_any as Dictionary).has("player"), "Tween registry missing 'player' key"
				)

			# Wait for cleanup.
			var ok_cleared := await _wait_for(
				runner,
				func() -> bool:
					if not loop.has_meta(_MOVE_TWEEN_META_KEY):
						return true
					var mm = loop.get_meta(_MOVE_TWEEN_META_KEY)
					return (mm is Dictionary) and not (mm as Dictionary).has("player"),
				_MAX_WAIT_FRAMES
			)
			runner._assert_true(
				ok_cleared, "Tween registry should clear 'player' after move completes"
			)
	)

	runner.add_test(
		"cutscene_move_to_anchor_fails_without_cutscene_actor_component",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			var flow = runtime.get("game_flow") if runtime != null else null
			runner._assert_true(runtime != null, "Runtime autoload missing")
			runner._assert_true(flow != null, "GameFlow missing")
			if runtime == null or flow == null:
				return

			flow.call("return_to_main_menu")
			await runner.get_tree().process_frame

			var ok_new: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")
			var gf: Node = runtime.get("game_flow") as Node
			if gf != null and gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			var player := runner.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			runner._assert_true(player != null, "Player should exist after start_new_game")
			if player == null:
				return

			# Ensure there is an anchor available in the active scene.
			var lr: LevelRoot = runtime.get_active_level_root() as LevelRoot
			runner._assert_true(lr != null, "Active LevelRoot missing")
			if lr == null:
				return

			var anchors: Node2D = lr.get_node_or_null(NodePath("CutsceneAnchors")) as Node2D
			if anchors == null:
				anchors = Node2D.new()
				anchors.name = "CutsceneAnchors"
				lr.add_child(anchors)
			var a: Node2D = anchors.get_node_or_null(NodePath("TestAnchor")) as Node2D
			if a == null:
				a = Marker2D.new()
				a.name = "TestAnchor"
				anchors.add_child(a)
			a.global_position = player.global_position + Vector2(5, 0)

			# Remove the required component from the player.
			var comp_any := ComponentFinder.find_component_in_group(
				player, &"cutscene_actor_components"
			)
			if comp_any != null and is_instance_valid(comp_any):
				comp_any.queue_free()
			await runner.get_tree().process_frame

			# Clear tween registry.
			var loop := Engine.get_main_loop()
			if loop != null and loop.has_meta(_MOVE_TWEEN_META_KEY):
				loop.set_meta(_MOVE_TWEEN_META_KEY, {})

			# Execute the event directly (wait=false so it doesn't need a Dialogic runtime).
			var ev_script := load("res://addons/dialogic_additions/Agents/event_move_to_anchor.gd")
			runner._assert_true(ev_script != null, "Failed to load event_move_to_anchor.gd")
			if ev_script == null:
				return
			var ev = ev_script.new()
			ev.agent_id = "player"
			ev.anchor_name = "TestAnchor"
			ev.speed = 60.0
			ev.wait = false
			ev.facing_dir = ""

			ev.call("_execute")
			await runner.get_tree().process_frame

			# Should not have registered any tween for player since component was missing.
			if loop != null and loop.has_meta(_MOVE_TWEEN_META_KEY):
				var m_any2 = loop.get_meta(_MOVE_TWEEN_META_KEY)
				if m_any2 is Dictionary:
					runner._assert_true(
						not (m_any2 as Dictionary).has("player"),
						"MoveToAnchor should not register tween without required component"
					)
	)

	runner.add_test(
		"dialogue_manager_cutscene_end_runs_deferred_restore_and_returns_to_running",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			var dm: Node = runner._get_autoload(&"DialogueManager")
			runner._assert_true(runtime != null, "Runtime autoload missing")
			runner._assert_true(dm != null, "DialogueManager autoload missing")
			if runtime == null or dm == null:
				return

			var flow = runtime.get("game_flow")
			if flow == null:
				runner._fail("GameFlow missing")
				return

			# Ensure we are in MENU state.
			flow.call("return_to_main_menu")
			await runner.get_tree().process_frame

			var ok_new: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")
			var gf: Node = runtime.get("game_flow") as Node
			if gf != null and gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			# Queue a deferred restore (no blackout in tests).
			runner._assert_true(
				dm.has_method("queue_cutscene_restore_after_timeline"),
				"DialogueManager.queue_cutscene_restore_after_timeline missing"
			)
			dm.call(
				"queue_cutscene_restore_after_timeline", PackedStringArray(["player"]), false, 0.0
			)

			var ended_ids: Array[StringName] = []
			var cb: Callable = func(timeline_id: StringName) -> void: ended_ids.append(timeline_id)
			dm.dialogue_ended.connect(cb)

			# Start a tiny cutscene that ends immediately.
			dm.call("start_cutscene", &"test_cutscene_end", null)

			var ok_end := await _wait_for(
				runner, func() -> bool: return ended_ids.size() >= 1, _MAX_WAIT_FRAMES
			)
			runner._assert_true(ok_end, "Cutscene should end and emit dialogue_ended")

			# Returns to RUNNING
			runner._assert_eq(
				int(runtime.flow_state),
				int(Enums.FlowState.RUNNING),
				"Runtime.flow_state should be RUNNING after cutscene ends"
			)

			# Deferred queue should be drained
			if "_deferred_restores" in dm:
				var q_any = dm.get("_deferred_restores")
				runner._assert_true(q_any is Array, "_deferred_restores should be an Array")
				if q_any is Array:
					runner._assert_eq(
						int((q_any as Array).size()),
						0,
						"Deferred restore queue should be empty after cutscene end"
					)

			# Snapshots cleared (either by consumption + clear)
			if "snapshotter" in dm:
				var snap = dm.get("snapshotter")
				if snap != null and "_cutscene_agent_snapshots" in snap:
					var d = snap.get("_cutscene_agent_snapshots")
					runner._assert_true(d is Dictionary, "Snapshot map should be a Dictionary")
					if d is Dictionary:
						runner._assert_true(
							(d as Dictionary).is_empty(),
							"Snapshot map should be empty after cutscene end"
						)

			# Clean up connection (avoid leaking callbacks across tests)
			if dm.dialogue_ended.is_connected(cb):
				dm.dialogue_ended.disconnect(cb)
	)

	runner.add_test(
		"dialogue_manager_dialogue_to_cutscene_chain_does_not_leak_fast_end",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			var dm: Node = runner._get_autoload(&"DialogueManager")
			runner._assert_true(runtime != null, "Runtime autoload missing")
			runner._assert_true(dm != null, "DialogueManager autoload missing")
			if runtime == null or dm == null:
				return

			var flow = runtime.get("game_flow")
			if flow == null:
				runner._fail("GameFlow missing")
				return

			# Ensure we are in MENU state.
			flow.call("return_to_main_menu")
			await runner.get_tree().process_frame

			var ok_new: bool = bool(await flow.call("start_new_game"))
			runner._assert_true(ok_new, "GameFlow.start_new_game should succeed")
			var gf: Node = runtime.get("game_flow") as Node
			if gf != null and gf.has_method("resume_game"):
				gf.call("resume_game")
			await runner.get_tree().process_frame

			# Simulate an active dialogue timeline (we don't need Dialogic to be running for this part).
			dm.set("_active", true)
			dm.set("_current_timeline_id", StringName("npcs/test/short_dialogue"))

			var ended_ids: Array[StringName] = []
			var cb: Callable = func(timeline_id: StringName) -> void: ended_ids.append(timeline_id)
			dm.dialogue_ended.connect(cb)

			# Request a cutscene while dialogue is "active": should queue + fast-end, then chain.
			runner._assert_true(
				dm.has_method("_on_cutscene_start_requested"),
				"DialogueManager._on_cutscene_start_requested missing"
			)
			dm.call("_on_cutscene_start_requested", &"test_cutscene_end", null)

			# Simulate the dialogue timeline ending now.
			runner._assert_true(
				dm.has_method("_on_facade_timeline_ended"),
				"DialogueManager._on_facade_timeline_ended missing"
			)
			await dm.call("_on_facade_timeline_ended", &"")

			# We should get two ended emissions:
			# 1) the simulated dialogue id, 2) the actual cutscene id.
			var ok_two := await _wait_for(
				runner, func() -> bool: return ended_ids.size() >= 2, _MAX_WAIT_FRAMES
			)
			runner._assert_true(ok_two, "Expected two dialogue_ended emissions for chain")
			if ended_ids.size() >= 2:
				runner._assert_eq(
					StringName(ended_ids[0]),
					StringName("npcs/test/short_dialogue"),
					"First ended id should be the dialogue timeline"
				)
				runner._assert_eq(
					StringName(ended_ids[1]),
					StringName("cutscenes/test_cutscene_end"),
					"Second ended id should be the chained cutscene timeline"
				)

			# Ensure we did not leak Dialogic fast-end suppression depth.
			if "facade" in dm:
				var facade = dm.get("facade")
				if facade != null and "_suppress_dialogic_ending_timeline_depth" in facade:
					runner._assert_eq(
						int(facade.get("_suppress_dialogic_ending_timeline_depth")),
						0,
						"Fast-end suppression depth should be 0 after chaining completes"
					)

			runner._assert_eq(
				int(runtime.flow_state),
				int(Enums.FlowState.RUNNING),
				"Runtime.flow_state should be RUNNING after chain completes"
			)

			if dm.dialogue_ended.is_connected(cb):
				dm.dialogue_ended.disconnect(cb)
	)
