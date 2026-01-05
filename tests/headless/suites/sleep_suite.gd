extends RefCounted


func register(runner: Node) -> void:
	runner.add_test(
		"time_manager_day_tick_at_6am",
		func() -> void:
			var tm = runner._get_autoload(&"TimeManager")
			var eb = runner._get_autoload(&"EventBus")
			tm.reset()

			var ticks := [0]
			var on_tick := func(_day): ticks[0] += 1
			eb.day_started.connect(on_tick)

			# 1. Start at 00:00. No tick yet.
			runner._assert_eq(tm.get_minute_of_day(), 0, "Should start at midnight")
			runner._assert_eq(ticks[0], 0, "No tick at midnight")

			# 2. Advance to 05:59. Still no tick.
			tm.set_minute_of_day(359)
			tm._process(0.01)
			runner._assert_eq(ticks[0], 0, "No tick at 05:59")

			# 3. Process into 06:00. Tick should fire.
			# Advance time manually by updating _elapsed_s indirectly via delta.
			tm._process(2.0)
			runner._assert_eq(ticks[0], 1, "Tick should fire when crossing 06:00")

			# 4. Stay at 06:01. No second tick.
			tm.set_minute_of_day(361)
			tm._process(0.01)
			runner._assert_eq(ticks[0], 1, "Tick should only fire once per day")

			eb.day_started.disconnect(on_tick)
	)

	runner.add_test(
		"time_manager_sleep_logic",
		func() -> void:
			var tm = runner._get_autoload(&"TimeManager")
			var eb = runner._get_autoload(&"EventBus")
			tm.reset()

			var ticks := [0]
			var on_tick := func(_day): ticks[0] += 1
			eb.day_started.connect(on_tick)

			# Case A: Sleep before 06:00.
			tm.set_minute_of_day(120)  # 02:00
			tm.sleep_to_6am()
			runner._assert_eq(tm.current_day, 1, "Day should not advance if sleeping before 06:00")
			runner._assert_eq(tm.get_minute_of_day(), 360, "Should wake at 06:00")
			runner._assert_eq(ticks[0], 1, "Sleep should trigger day tick")

			# Case B: Sleep after 06:00.
			tm.set_minute_of_day(600)  # 10:00
			tm.sleep_to_6am()
			runner._assert_eq(tm.current_day, 2, "Day should advance if sleeping after 06:00")
			runner._assert_eq(tm.get_minute_of_day(), 360, "Should wake at 06:00")
			runner._assert_eq(ticks[0], 2, "Sleep should trigger day tick again for next day")

			eb.day_started.disconnect(on_tick)
	)

	runner.add_test(
		"time_manager_set_minute_no_side_effects",
		func() -> void:
			# Verify that loading a save (via set_minute_of_day) doesn't fire ticks.
			var tm = runner._get_autoload(&"TimeManager")
			var eb = runner._get_autoload(&"EventBus")
			tm.reset()

			var ticks := [0]
			var on_tick := func(_day): ticks[0] += 1
			eb.day_started.connect(on_tick)

			tm.set_minute_of_day(400)  # Past 06:00
			runner._assert_eq(
				ticks[0], 0, "set_minute_of_day should NOT trigger day tick (for save-load safety)"
			)

			eb.day_started.disconnect(on_tick)
	)

	runner.add_test(
		"sleep_interaction_triggers_loading_blackout",
		func() -> void:
			var runtime := runner._get_autoload(&"Runtime")
			runner._assert_true(runtime != null, "Runtime autoload missing")
			# Ensure Runtime has a level + WorldGrid so day tick completion can run.
			await runtime.start_new_game()

			var ui := runner._get_autoload(&"UIManager")
			runner._assert_true(ui != null, "UIManager autoload missing")

			var bed_scene := load("res://game/entities/bed/bed.tscn") as PackedScene
			runner._assert_true(bed_scene != null, "Failed to load bed.tscn")
			var bed := bed_scene.instantiate()
			runner._assert_true(bed != null, "Failed to instantiate bed.tscn")
			runner.get_tree().root.add_child(bed)

			var sleep := bed.get_node_or_null(NodePath("Components/SleepOnInteract"))
			runner._assert_true(sleep != null, "Bed missing Components/SleepOnInteract")

			# Make the test fast but give us a small window to observe the blackout.
			sleep.fade_in_seconds = 0.0
			sleep.hold_black_seconds = 0.2
			sleep.hold_after_tick_seconds = 0.0
			sleep.fade_out_seconds = 0.0

			var ctx := InteractionContext.new()
			ctx.kind = InteractionContext.Kind.USE

			# Kick off sleep and verify loading screen goes fully black during the hold.
			sleep.try_interact(ctx)
			await runner.get_tree().process_frame
			await runner.get_tree().create_timer(0.05).timeout

			var loading := ui.get_screen_node(ui.ScreenName.LOADING_SCREEN)
			runner._assert_true(
				loading != null, "LoadingScreen should be instantiated during sleep"
			)
			if loading != null and "color_rect" in loading:
				runner._assert_true(
					loading.color_rect.visible,
					"LoadingScreen ColorRect should be visible during blackout"
				)
				runner._assert_true(
					float(loading.color_rect.color.a) >= 0.99,
					"LoadingScreen should be fully opaque (black) during blackout hold"
				)

			# Let sleep finish and ensure the blackout is released.
			await runner.get_tree().create_timer(0.3).timeout
			loading = ui.get_screen_node(ui.ScreenName.LOADING_SCREEN)
			if loading != null and "color_rect" in loading:
				runner._assert_true(
					not loading.color_rect.visible,
					"LoadingScreen ColorRect should be hidden after sleep completes"
				)
	)
