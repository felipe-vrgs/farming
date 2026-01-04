extends RefCounted

func register(runner: Node) -> void:
	runner.add_test("agent_registry_commit_travel_invariant", func() -> void:
		var reg := AgentRegistry.new()
		reg.active_level_id = Enums.Levels.ISLAND

		var sp_path := "res://data/spawn_points/island/player_spawn.tres"
		runner._assert_true(
			ResourceLoader.exists(sp_path),
			"Missing SpawnPointData resource for tests: player_spawn.tres"
		)
		var sp := load(sp_path) as SpawnPointData
		runner._assert_true(sp != null and sp.is_valid(), "SpawnPointData should load and be valid")

		var ok := reg.commit_travel_by_id(&"player", sp)
		runner._assert_true(ok, "commit_travel_by_id should succeed")

		var rec := reg.get_record(&"player") as AgentRecord
		runner._assert_true(rec != null, "Registry should create/get player AgentRecord")
		runner._assert_eq(
			int(rec.current_level_id),
			int(sp.level_id),
			"commit_travel_by_id should set current_level_id"
		)
		runner._assert_eq(
			String(rec.last_spawn_point_path),
			String(sp.resource_path),
			"commit_travel_by_id should set spawn point path"
		)
		runner._assert_eq(
			rec.last_world_pos,
			sp.position,
			"commit_travel_by_id should set last_world_pos to spawn pos"
		)
	)
