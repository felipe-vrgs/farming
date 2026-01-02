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
		"res://entities/items/resources/item_%s.tres" % item_id,
		"res://entities/items/resources/%s.tres" % item_id,
		"res://entities/items/%s.tres" % item_id
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
