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
