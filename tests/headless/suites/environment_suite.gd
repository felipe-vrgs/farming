extends RefCounted


func register(runner: Node) -> void:
	runner.add_test(
		"environment_simulator_rules",
		func() -> void:
			# Wet soil decays to soil after a day.
			runner._assert_eq(
				EnvironmentSimulator.predict_soil_decay(GridCellData.TerrainType.SOIL_WET),
				GridCellData.TerrainType.SOIL,
				"SOIL_WET should decay to SOIL"
			)
			# Normal soil does not decay (v1 rule).
			runner._assert_eq(
				EnvironmentSimulator.predict_soil_decay(GridCellData.TerrainType.SOIL),
				GridCellData.TerrainType.SOIL,
				"SOIL should remain SOIL"
			)
			# Plant growth only advances when wet.
			runner._assert_eq(
				EnvironmentSimulator.predict_plant_growth(0, 3, false),
				0,
				"Dry soil should not grow plant"
			)
			runner._assert_eq(
				EnvironmentSimulator.predict_plant_growth(0, 3, true),
				1,
				"Wet soil should grow plant by +1 day"
			)
			# Growth clamps to days_to_grow if provided.
			runner._assert_eq(
				EnvironmentSimulator.predict_plant_growth(3, 3, true),
				3,
				"Growth should clamp to days_to_grow"
			)
	)

	runner.add_test(
		"offline_environment_adapter_apply",
		func() -> void:
			# Build a tiny offline level save with one wet cell + one plant.
			var ls := LevelSave.new()
			ls.level_id = Enums.Levels.ISLAND

			var cell := Vector2i(10, 10)
			var cs := CellSnapshot.new()
			cs.coords = cell
			cs.terrain_id = int(GridCellData.TerrainType.SOIL_WET)
			ls.cells = [cs]

			var plant_path := "res://tests/fixtures/test_plant_data.tres"
			runner._assert_true(ResourceLoader.exists(plant_path), "Missing test PlantData fixture")

			var es := EntitySnapshot.new()
			es.scene_path = "res://entities/plants/plant.tscn"
			es.entity_type = int(Enums.EntityType.PLANT)
			es.grid_pos = cell
			es.state = {"data": plant_path, "days_grown": 0}
			ls.entities = [es]

			var adapter := OfflineEnvironmentAdapter.new(ls)
			var res := EnvironmentSimulator.simulate_day(adapter)
			runner._assert_true(res != null, "simulate_day should return a result")

			# Apply should mutate the snapshots in-place.
			adapter.apply_result(res)

			# Wet soil should have decayed to SOIL in the snapshot.
			runner._assert_eq(
				int(cs.terrain_id),
				int(GridCellData.TerrainType.SOIL),
				"Offline adapter should apply soil decay to CellSnapshot"
			)
			# Plant should have advanced 0 -> 1 day (wet).
			runner._assert_eq(
				int(es.state.get("days_grown", -1)),
				1,
				"Offline adapter should apply plant growth to EntitySnapshot state"
			)
	)

	runner.add_test(
		"environment_simulator_full_simulation",
		func() -> void:
			# Test simulate_day with multiple entities and cells
			var ls := LevelSave.new()
			ls.level_id = Enums.Levels.ISLAND

			# Cell 1: Wet -> Soil
			var cs1 := CellSnapshot.new()
			cs1.coords = Vector2i(0, 0)
			cs1.terrain_id = int(GridCellData.TerrainType.SOIL_WET)

			# Cell 2: Soil -> Soil
			var cs2 := CellSnapshot.new()
			cs2.coords = Vector2i(1, 1)
			cs2.terrain_id = int(GridCellData.TerrainType.SOIL)

			ls.cells = [cs1, cs2]

			# Plant 1: On Wet cell -> Grows
			var es1 := EntitySnapshot.new()
			es1.grid_pos = Vector2i(0, 0)
			es1.entity_type = int(Enums.EntityType.PLANT)
			es1.state = {"data": "res://tests/fixtures/test_plant_data.tres", "days_grown": 0}

			# Plant 2: On Dry cell -> Doesn't grow
			var es2 := EntitySnapshot.new()
			es2.grid_pos = Vector2i(1, 1)
			es2.entity_type = int(Enums.EntityType.PLANT)
			es2.state = {"data": "res://tests/fixtures/test_plant_data.tres", "days_grown": 0}

			ls.entities = [es1, es2]

			var adapter := OfflineEnvironmentAdapter.new(ls)
			var res := EnvironmentSimulator.simulate_day(adapter)
			adapter.apply_result(res)

			runner._assert_eq(
				int(cs1.terrain_id), int(GridCellData.TerrainType.SOIL), "Cell 1 should be dry"
			)
			runner._assert_eq(
				int(cs2.terrain_id), int(GridCellData.TerrainType.SOIL), "Cell 2 should remain dry"
			)
			runner._assert_eq(int(es1.state["days_grown"]), 1, "Plant 1 should have grown")
			runner._assert_eq(int(es2.state["days_grown"]), 0, "Plant 2 should NOT have grown")
	)
