extends RefCounted

## Regression tests for DialogueManager lifecycle and chaining.
## These tests are intentionally lightweight and use tiny timelines that end immediately.

const _MAX_WAIT_FRAMES := 90


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
		"dialogue_manager_cutscene_end_runs_deferred_restore_and_returns_to_running",
		func() -> void:
			var runtime = runner._get_autoload(&"Runtime")
			var dm: Node = runner._get_autoload(&"DialogueManager")
			runner._assert_true(runtime != null, "Runtime autoload missing")
			runner._assert_true(dm != null, "DialogueManager autoload missing")
			if runtime == null or dm == null:
				return

			var ok_new: bool = bool(await runtime.call("start_new_game"))
			runner._assert_true(ok_new, "Runtime.start_new_game should succeed")
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

			var ok_new: bool = bool(await runtime.call("start_new_game"))
			runner._assert_true(ok_new, "Runtime.start_new_game should succeed")
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
