extends RefCounted

const _TMP_DIR := "user://test_routes"
const _AGENT_BRAIN_SCRIPT: Script = preload("res://game/globals/agent/agent_brain.gd")


func register(runner: Node) -> void:
	runner.add_test(
		"agent_schedule_chaining_sets_override_and_prevents_snapback",
		func() -> void:
			var tmp_paths: Array[String] = []

			var brain := _make_brain()
			var npc_id := &"npc_test_chain"
			var cfg := NpcConfig.new()
			cfg.npc_id = npc_id

			# Create 2 distinct route resources with stable resource_path (saved to user://).
			var route0 := _save_route(
				runner,
				"agent_schedule_chain_route0",
				[
					_wp(Enums.Levels.ISLAND, Vector2(10, 10)),
					_wp(Enums.Levels.ISLAND, Vector2(20, 20)),
				],
				tmp_paths
			)
			var route1 := _save_route(
				runner,
				"agent_schedule_chain_route1",
				[
					_wp(Enums.Levels.ISLAND, Vector2(30, 30)),
					_wp(Enums.Levels.ISLAND, Vector2(40, 40)),
				],
				tmp_paths
			)

			var schedule := NpcSchedule.new()
			schedule.steps = [
				_step_route(6 * 60, 6 * 60, route0, false),  # 06:00-12:00 non-loop
				_step_route(12 * 60, 60, route1, false),  # 12:00-13:00 non-loop
			]
			cfg.schedule = schedule

			# Install config in spawner lookup.
			brain.spawner._npc_configs[npc_id] = cfg

			# Create registry record.
			var rec := AgentRecord.new()
			rec.agent_id = npc_id
			rec.kind = Enums.AgentKind.NPC
			rec.current_level_id = Enums.Levels.ISLAND
			rec.last_world_pos = Vector2(0, 0)
			brain.registry.upsert_record(rec)

			# Create tracker and order.
			var tracker := AgentRouteTracker.new()
			tracker.agent_id = npc_id
			brain._trackers[npc_id] = tracker

			var order := AgentOrder.new()
			order.agent_id = npc_id
			brain._orders[npc_id] = order

			# Set time to 07:00 -> still inside step0 window.
			TimeManager.set_minute_of_day(7 * 60)

			# Put tracker at end of route0, then trigger completion.
			var route_key0 := StringName("route:" + String(route0.resource_path))
			var route_key1 := StringName("route:" + String(route1.resource_path))
			tracker.set_route(
				route_key0, route0.waypoints, rec.last_world_pos, rec.current_level_id, false, false
			)
			tracker.waypoint_idx = tracker.waypoints.size() - 1

			brain._on_agent_reached_target(npc_id)

			runner._assert_eq(
				String(tracker.route_key),
				String(route_key1),
				"Chaining should switch tracker to next route"
			)

			var info: Dictionary = brain.debug_get_schedule_override_info(npc_id)
			runner._assert_true(
				not info.is_empty(),
				"Chaining early should create a schedule override to prevent snapback"
			)
			runner._assert_eq(
				int(info.get("expire_minute", -1)),
				12 * 60,
				"Override should expire at next step start (12:00)"
			)

			# Next minute tick still resolves schedule step0; override should swap to step1.
			var resolved := ScheduleResolver.resolve(schedule, (7 * 60) + 1)
			runner._assert_eq(
				resolved.step_index,
				0,
				"Sanity: schedule resolver should still be on step0 at 07:01"
			)
			brain._apply_schedule_override(npc_id, schedule, (7 * 60) + 1, resolved)
			runner._assert_eq(
				resolved.step_index, 1, "Override should replace resolved step to prevent snapback"
			)

			# Once time reaches 12:00, the override should clear.
			var resolved2 := ScheduleResolver.resolve(schedule, 12 * 60)
			brain._apply_schedule_override(npc_id, schedule, 12 * 60, resolved2)
			var info2: Dictionary = brain.debug_get_schedule_override_info(npc_id)
			runner._assert_true(info2.is_empty(), "Override should clear at/after expiry minute")

			_cleanup_tmp_paths(tmp_paths)
	)

	runner.add_test(
		"agent_schedule_hold_snaps_to_spawn_point",
		func() -> void:
			var tmp_paths: Array[String] = []

			var brain := _make_brain()
			var npc_id := &"npc_test_hold"
			var cfg := NpcConfig.new()
			cfg.npc_id = npc_id

			var route := _save_route(
				runner,
				"agent_schedule_hold_route",
				[
					_wp(Enums.Levels.ISLAND, Vector2(10, 10)),
					_wp(Enums.Levels.ISLAND, Vector2(20, 20)),
				],
				tmp_paths
			)

			# HOLD from 08:00-09:00.
			var hold_sp := _save_spawn_point(
				runner, "agent_schedule_hold_sp", Enums.Levels.ISLAND, Vector2(99, 99), tmp_paths
			)
			var schedule := NpcSchedule.new()
			schedule.steps = [_step_hold(8 * 60, 60, hold_sp)]
			cfg.schedule = schedule

			brain.spawner._npc_configs[npc_id] = cfg

			var rec := AgentRecord.new()
			rec.agent_id = npc_id
			rec.kind = Enums.AgentKind.NPC
			rec.current_level_id = Enums.Levels.ISLAND
			rec.last_world_pos = Vector2(0, 0)
			brain.registry.upsert_record(rec)

			var tracker := AgentRouteTracker.new()
			tracker.agent_id = npc_id
			var route_key := StringName("route:" + String(route.resource_path))
			tracker.set_route(
				route_key, route.waypoints, rec.last_world_pos, rec.current_level_id, false, false
			)

			TimeManager.set_minute_of_day(8 * 60)
			var resolved := ScheduleResolver.resolve(schedule, 8 * 60)
			runner._assert_true(
				resolved.step != null and resolved.step.kind == NpcScheduleStep.Kind.HOLD,
				"Sanity: resolved step should be HOLD"
			)

			var order = brain._compute_order(rec, cfg, tracker, resolved)
			runner._assert_eq(
				int(order.action),
				int(AgentOrder.Action.IDLE),
				"During HOLD, NPC should snap to the configured spawn point"
			)
			var rec2 := brain.registry.get_record(npc_id) as AgentRecord
			runner._assert_true(rec2 != null, "Record should still exist after snap")
			runner._assert_eq(
				int(rec2.current_level_id), int(Enums.Levels.ISLAND), "Should remain on island"
			)
			runner._assert_eq(
				rec2.last_world_pos, Vector2(99, 99), "Should snap to hold spawn point pos"
			)

			_cleanup_tmp_paths(tmp_paths)
	)

	runner.add_test(
		"agent_schedule_does_not_chain_when_next_step_is_hold",
		func() -> void:
			var tmp_paths: Array[String] = []

			var brain := _make_brain()
			var npc_id := &"npc_test_no_chain"
			var cfg := NpcConfig.new()
			cfg.npc_id = npc_id

			var route0 := _save_route(
				runner,
				"agent_schedule_no_chain_route0",
				[
					_wp(Enums.Levels.ISLAND, Vector2(10, 10)),
					_wp(Enums.Levels.ISLAND, Vector2(20, 20)),
				],
				tmp_paths
			)

			# Step0 ROUTE then next step HOLD.
			var schedule := NpcSchedule.new()
			schedule.steps = [
				_step_route(6 * 60, 6 * 60, route0, false),
				_step_hold(12 * 60, 60),
			]
			cfg.schedule = schedule
			brain.spawner._npc_configs[npc_id] = cfg

			var rec := AgentRecord.new()
			rec.agent_id = npc_id
			rec.kind = Enums.AgentKind.NPC
			rec.current_level_id = Enums.Levels.ISLAND
			rec.last_world_pos = Vector2(0, 0)
			brain.registry.upsert_record(rec)

			var tracker := AgentRouteTracker.new()
			tracker.agent_id = npc_id
			brain._trackers[npc_id] = tracker

			var order := AgentOrder.new()
			order.agent_id = npc_id
			brain._orders[npc_id] = order

			TimeManager.set_minute_of_day(7 * 60)

			var route_key0 := StringName("route:" + String(route0.resource_path))
			tracker.set_route(
				route_key0, route0.waypoints, rec.last_world_pos, rec.current_level_id, false, false
			)
			tracker.waypoint_idx = tracker.waypoints.size() - 1

			brain._on_agent_reached_target(npc_id)

			(
				runner
				. _assert_true(
					not tracker.is_active(),
					"With no next ROUTE step, finishing a non-loop route should complete and become inactive"
				)
			)
			runner._assert_true(
				brain.debug_get_schedule_override_info(npc_id).is_empty(),
				"No override should be set when chaining does not occur"
			)

			_cleanup_tmp_paths(tmp_paths)
	)

	runner.add_test(
		"offline_sim_cross_level_advance_keeps_order_target_in_sync",
		func() -> void:
			# Regression: when offline sim teleports to another level and advances the tracker,
			# it must also update the current AgentOrder target_position so that a freshly spawned
			# online NPC doesn't immediately "reach" an old waypoint and skip ahead.
			var npc_id := &"npc_test_offline_teleport_sync"

			var registry := AgentRegistry.new()
			registry.active_level_id = Enums.Levels.FRIEREN_HOUSE  # destination is active

			var rec := AgentRecord.new()
			rec.agent_id = npc_id
			rec.kind = Enums.AgentKind.NPC
			rec.current_level_id = Enums.Levels.ISLAND
			rec.last_world_pos = Vector2(0, 0)
			registry.upsert_record(rec)

			var wp_a := _wp(Enums.Levels.ISLAND, Vector2(10, 10))
			var wp_b_exit := _wp(Enums.Levels.FRIEREN_HOUSE, Vector2(30, 30))
			var wp_b_next := _wp(Enums.Levels.FRIEREN_HOUSE, Vector2(60, 60))

			var tracker := AgentRouteTracker.new()
			tracker.agent_id = npc_id
			tracker.set_route(
				&"route:test",
				[wp_a, wp_b_exit, wp_b_next],
				rec.last_world_pos,
				rec.current_level_id,
				false,
				false
			)
			# Simulate: agent has reached waypoint 0 and is now targeting the cross-level
			# exit waypoint (idx=1).
			tracker.waypoint_idx = 1

			var order := AgentOrder.new()
			order.agent_id = npc_id
			order.action = AgentOrder.Action.MOVE_TO
			order.target_position = wp_b_exit.position  # stale target (pre-teleport)

			var result := AgentOfflineSim.apply_order(rec, order, tracker, 10.0, registry)

			runner._assert_true(
				result.committed_travel,
				"Offline sim should commit travel when waypoint is in another level"
			)
			runner._assert_eq(
				int(rec.current_level_id),
				int(Enums.Levels.FRIEREN_HOUSE),
				"After teleport, record should be in destination level"
			)
			runner._assert_eq(
				int(tracker.waypoint_idx),
				2,
				"Tracker should advance to next waypoint after teleport"
			)
			runner._assert_eq(
				order.target_position,
				wp_b_next.position,
				"Order target_position must match advanced tracker target"
			)
	)


func _make_brain() -> Node:
	var brain = _AGENT_BRAIN_SCRIPT.new()
	brain.registry = AgentRegistry.new()
	brain.spawner = AgentSpawner.new()
	brain.spawner.setup(brain.registry)
	return brain


func _wp(level_id: Enums.Levels, pos: Vector2) -> WorldPoint:
	var wp := WorldPoint.new()
	wp.level_id = level_id
	wp.position = pos
	return wp


func _step_route(
	start_minute: int, duration: int, route: RouteResource, loop_route: bool
) -> NpcScheduleStep:
	var s := NpcScheduleStep.new()
	s.kind = NpcScheduleStep.Kind.ROUTE
	s.start_minute_of_day = start_minute
	s.duration_minutes = duration
	s.route_res = route
	s.loop_route = loop_route
	return s


func _step_hold(start_minute: int, duration: int, sp: SpawnPointData = null) -> NpcScheduleStep:
	var s := NpcScheduleStep.new()
	s.kind = NpcScheduleStep.Kind.HOLD
	s.start_minute_of_day = start_minute
	s.duration_minutes = duration
	s.hold_spawn_point = sp
	return s


func _save_route(
	runner: Node, name: String, waypoints: Array[WorldPoint], tmp_paths: Array[String]
) -> RouteResource:
	var abs_dir := ProjectSettings.globalize_path(_TMP_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var route := RouteResource.new()
	route.route_name = StringName(name)
	route.waypoints = waypoints

	var path := _TMP_DIR + "/%s.tres" % name
	tmp_paths.append(path)

	var err := ResourceSaver.save(route, path)
	runner._assert_eq(err, OK, "ResourceSaver should save route resource for tests")

	var loaded := load(path) as RouteResource
	runner._assert_true(loaded != null, "Saved route should load in tests")
	runner._assert_true(
		not String(loaded.resource_path).is_empty(), "Saved route should have a resource_path"
	)
	return loaded


func _save_spawn_point(
	runner: Node, name: String, level_id: Enums.Levels, pos: Vector2, tmp_paths: Array[String]
) -> SpawnPointData:
	var abs_dir := ProjectSettings.globalize_path(_TMP_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var sp := SpawnPointData.new()
	sp.level_id = level_id
	sp.position = pos
	sp.display_name = name

	var path := _TMP_DIR + "/%s_spawn.tres" % name
	tmp_paths.append(path)

	var err := ResourceSaver.save(sp, path)
	runner._assert_eq(err, OK, "ResourceSaver should save spawn point resource for tests")

	var loaded := load(path) as SpawnPointData
	runner._assert_true(loaded != null, "Saved spawn point should load in tests")
	runner._assert_true(
		not String(loaded.resource_path).is_empty(), "Saved spawn point should have a resource_path"
	)
	return loaded


func _cleanup_tmp_paths(paths: Array[String]) -> void:
	for p in paths:
		var abs_path := ProjectSettings.globalize_path(p)
		if abs_path.is_empty():
			continue
		# Best-effort cleanup; never fail tests due to cleanup issues.
		DirAccess.remove_absolute(abs_path)
