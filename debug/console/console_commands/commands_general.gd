class_name CommandsGeneral
extends ConsoleCommandModule


func get_category() -> String:
	return "General"


func _register_commands() -> void:
	_cmd("clear", _cmd_clear, "Clears the console log")
	_cmd("quit", _cmd_quit, "Quits the game")
	_cmd("give", _cmd_give, "Usage: give <item_id> [amount]")
	_cmd("time", _cmd_time, "Usage: time [skip|scale <float>|set_minute <m>]")
	_cmd("travel", _cmd_travel, "Usage: travel <level_id> (Moves PLAYER)")
	_cmd("house_tier", _cmd_house_tier, "Usage: house_tier [tier]")
	_cmd("rain", _cmd_rain, "Usage: rain [on|off|toggle] [intensity 0-1]")


func _cmd_clear(_args: Array) -> void:
	if _console and _console.log_display:
		_console.log_display.clear()


func _cmd_quit(_args: Array) -> void:
	_console.get_tree().quit()


func _cmd_give(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: give <item_id> [amount]", "yellow")
		return

	var item_id = args[0]
	var amount = 1
	if args.size() > 1:
		amount = int(args[1])

	var player = _console.get_tree().get_first_node_in_group(Groups.PLAYER)
	if not player:
		_print("Error: Player not found. Is the scene loaded?", "red")
		return

	# Try to find the resource by name in standard paths
	var valid_paths = [
		"res://game/entities/items/resources/item_%s.tres" % item_id,
		"res://game/entities/items/resources/%s.tres" % item_id,
		"res://game/entities/items/%s.tres" % item_id
	]

	var item_data: ItemData = null
	for path in valid_paths:
		if ResourceLoader.exists(path):
			item_data = load(path) as ItemData
			if item_data:
				break

	if not item_data:
		_print("Error: Could not find item resource for '%s'" % item_id, "red")
		return

	var leftover = player.inventory.add_item(item_data, amount)
	if leftover == 0:
		_print(str("Gave %d x %s" % [amount, item_data.display_name]), "green")
	else:
		_print(
			str("Gave %d x %s (Inventory full!)") % [amount - leftover, item_data.display_name],
			"yellow"
		)


func _cmd_time(args: Array) -> void:
	if args.is_empty():
		var day = str(TimeManager.current_day) if TimeManager else "?"
		var tod := "?"
		if TimeManager:
			tod = "%02d:%02d" % [int(TimeManager.get_hour()), int(TimeManager.get_minute())]
		_print(str("Current Day: %s  Time: %s") % [day, tod])
		return

	var sub = args[0]
	if sub == "skip":
		if TimeManager:
			TimeManager.advance_day()
			_print("Skipped to Day %d" % TimeManager.current_day, "green")
	elif sub == "set_minute":
		if TimeManager == null:
			return
		if args.size() < 2:
			_print("Usage: time set_minute <0-1439>", "yellow")
			return
		var m := int(args[1])
		TimeManager.set_minute_of_day(m)
		_print(
			"Time set to %02d:%02d" % [int(TimeManager.get_hour()), int(TimeManager.get_minute())],
			"green"
		)
	elif sub == "scale":
		if args.size() > 1:
			var s = float(args[1])
			Engine.time_scale = s
			_print("Time scale: %.2f" % s)
		else:
			_print("Current time scale: %.2f" % Engine.time_scale)


func _cmd_travel(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: travel <level_id>", "yellow")
		return
	var level_id := StringName(String(args[0]))
	if Runtime == null:
		_print("Error: Runtime not found.", "red")
		return
	var ok: bool = await Runtime.travel_to_level(Enums.Levels.get(level_id))
	if ok:
		_print("Traveled to '%s'." % String(level_id), "green")
	else:
		_print("Failed to travel to '%s'." % String(level_id), "red")


func _cmd_house_tier(args: Array) -> void:
	if Runtime == null:
		_print("Error: Runtime not found.", "red")
		return
	if args.is_empty():
		var tier := Runtime.get_tier(&"frieren_house", 0) if Runtime.has_method("get_tier") else 0
		_print("Frieren house tier: %d" % int(tier), "white")
		return
	var tier_value := int(args[0])
	if Runtime.has_method("set_tier"):
		Runtime.set_tier(&"frieren_house", tier_value)
		_print("Frieren house tier set to %d." % tier_value, "green")
	else:
		_print("Error: set_tier not available.", "red")


func _cmd_rain(args: Array) -> void:
	if WeatherManager == null:
		_print("Error: WeatherManager not found.", "red")
		return

	var enabled := WeatherManager.is_raining()
	var intensity := -1.0

	if args.size() >= 1:
		var mode := String(args[0])
		if mode == "on":
			enabled = true
		elif mode == "off":
			enabled = false
		elif mode == "toggle":
			enabled = not enabled
		else:
			_print("Usage: rain [on|off|toggle] [intensity 0-1]", "yellow")
			return

	if args.size() >= 2:
		intensity = clampf(float(args[1]), 0.0, 1.0)

	WeatherManager.set_raining(enabled, intensity)
	if enabled:
		var v := WeatherManager.rain_intensity
		_print("Rain enabled (intensity %.2f)." % float(v), "green")
	else:
		_print("Rain disabled.", "green")
