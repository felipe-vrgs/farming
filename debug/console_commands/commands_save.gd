class_name CommandsSave
extends ConsoleCommandModule

func get_category() -> String:
	return "Save/Load"

func _register_commands() -> void:
	_cmd("save", _cmd_save, "Save the game")
	_cmd("load", _cmd_load, "Load the game")
	_cmd("continue", _cmd_continue, "Continue from session (autosave)")
	_cmd("save_slot", _cmd_save_slot, "Usage: save_slot <slot>")
	_cmd("load_slot", _cmd_load_slot, "Usage: load_slot <slot>")
	_cmd("slots", _cmd_slots, "List save slots")
	_cmd("save_dump", _cmd_save_dump, "Usage: save_dump session|slot <name> (prints save summaries)")
	_cmd("save_dump_agents",
		_cmd_save_dump_agents,
		"Usage: save_dump_agents session|slot <name> (prints AgentRecords)"
	)
	_cmd("save_dump_levels",
		_cmd_save_dump_levels,
		"Usage: save_dump_levels session|slot <name> (lists LevelSave ids)"
	)

func _cmd_save(_args: Array) -> void:
	if GameManager != null and GameManager.save_to_slot("default"):
		_print("Game saved successfully.", "green")
	else:
		_print("Failed to save game.", "red")

func _cmd_load(_args: Array) -> void:
	var success = false
	if GameManager != null:
		success = await GameManager.load_from_slot("default")
	if success:
		_print("Game loaded successfully.", "green")
	else:
		_print("Failed to load game.", "red")

func _cmd_continue(_args: Array) -> void:
	var success = false
	if GameManager != null:
		success = await GameManager.continue_session()
	if success:
		_print("Continued session successfully.", "green")
	else:
		_print("Failed to continue session.", "red")

func _cmd_save_slot(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: save_slot <slot>", "yellow")
		return
	var slot := String(args[0])
	if GameManager != null and GameManager.save_to_slot(slot):
		_print("Saved slot '%s'." % slot, "green")
	else:
		_print("Failed to save slot '%s'." % slot, "red")

func _cmd_load_slot(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: load_slot <slot>", "yellow")
		return
	var slot := String(args[0])
	var success = false
	if GameManager != null:
		success = await GameManager.load_from_slot(slot)
	if success:
		_print("Loaded slot '%s'." % slot, "green")
	else:
		_print("Failed to load slot '%s'." % slot, "red")

func _cmd_slots(_args: Array) -> void:
	if SaveManager == null:
		_print("Error: SaveManager not found.", "red")
		return
	var slots := SaveManager.list_slots()
	if slots.is_empty():
		_print("(no slots)", "yellow")
		return
	_print("--- Slots ---", "yellow")
	for s in slots:
		var t := int(SaveManager.get_slot_modified_unix(s))
		_print("%s (mtime=%d)" % [s, t], "white")

func _cmd_save_dump(args: Array) -> void:
	if SaveManager == null:
		_print("Error: SaveManager not found.", "red")
		return
	if args.size() < 1:
		_print("Usage: save_dump session|slot <name>", "yellow")
		return

	var scope := String(args[0])
	var scope_name := String(args[1]) if args.size() > 1 else ""

	if scope == "session":
		_dump_session_summary()
		return
	if scope == "slot":
		if scope_name.is_empty():
			_print("Usage: save_dump slot <slot_name>", "yellow")
			return
		_dump_slot_summary(scope_name)
		return

	_print("Usage: save_dump session|slot <name>", "yellow")

func _cmd_save_dump_agents(args: Array) -> void:
	if SaveManager == null:
		_print("Error: SaveManager not found.", "red")
		return
	if args.size() < 1:
		_print("Usage: save_dump_agents session|slot <name>", "yellow")
		return

	var scope := String(args[0])
	var scope_name := String(args[1]) if args.size() > 1 else ""

	var a: AgentsSave = null
	if scope == "session":
		a = SaveManager.load_session_agents_save()
	elif scope == "slot":
		if scope_name.is_empty():
			_print("Usage: save_dump_agents slot <slot_name>", "yellow")
			return
		a = SaveManager.load_slot_agents_save(scope_name)
	else:
		_print("Usage: save_dump_agents session|slot <name>", "yellow")
		return

	if a == null:
		_print("(no agents save)", "yellow")
		return

	_print("--- AgentsSave ---", "yellow")
	_print("agents=%d" % a.agents.size(), "white")
	for rec in a.agents:
		if rec == null:
			continue
		_print(_format_agent_record(rec), "white")

func _cmd_save_dump_levels(args: Array) -> void:
	if SaveManager == null:
		_print("Error: SaveManager not found.", "red")
		return
	if args.size() < 1:
		_print("Usage: save_dump_levels session|slot <name>", "yellow")
		return

	var scope := String(args[0])
	var scope_name := String(args[1]) if args.size() > 1 else ""

	var level_ids: Array[Enums.Levels] = []
	if scope == "session":
		level_ids = SaveManager.list_session_level_ids()
	elif scope == "slot":
		if scope_name.is_empty():
			_print("Usage: save_dump_levels slot <slot_name>", "yellow")
			return
		level_ids = SaveManager.list_slot_level_ids(scope_name)
	else:
		_print("Usage: save_dump_levels session|slot <name>", "yellow")
		return

	if level_ids.is_empty():
		_print("(no level saves)", "yellow")
		return

	_print("--- LevelSaves ---", "yellow")
	for lid in level_ids:
		_print("level_id=%s" % str(int(lid)), "white")

func _dump_session_summary() -> void:
	var gs := SaveManager.load_session_game_save()
	var a := SaveManager.load_session_agents_save()
	var levels := SaveManager.list_session_level_ids()

	_print("--- Session Save Summary ---", "yellow")
	if gs == null:
		_print("GameSave: (missing)", "yellow")
	else:
		_print(
			"GameSave: day=%d active_level_id=%d" % [int(gs.current_day), int(gs.active_level_id)],
			"white"
		)
	if a == null:
		_print("AgentsSave: (missing)", "yellow")
	else:
		_print("AgentsSave: agents=%d" % a.agents.size(), "white")
	_print("LevelSaves: %d" % levels.size(), "white")

func _dump_slot_summary(slot: String) -> void:
	var gs := SaveManager.load_slot_game_save(slot)
	var a := SaveManager.load_slot_agents_save(slot)
	var levels := SaveManager.list_slot_level_ids(slot)

	_print("--- Slot Save Summary: %s ---" % slot, "yellow")
	if gs == null:
		_print("GameSave: (missing)", "yellow")
	else:
		_print(
			"GameSave: day=%d active_level_id=%d" % [int(gs.current_day), int(gs.active_level_id)],
			"white"
		)
	if a == null:
		_print("AgentsSave: (missing)", "yellow")
	else:
		_print("AgentsSave: agents=%d" % a.agents.size(), "white")
	_print("LevelSaves: %d" % levels.size(), "white")

func _format_agent_record(rec: AgentRecord) -> String:
	return "%s kind=%d level=%d pos=%s cell=%s money=%d last_spawn=%d pending=(%d,%d)" % [
		String(rec.agent_id),
		int(rec.kind),
		int(rec.current_level_id),
		str(rec.last_world_pos),
		str(rec.last_cell),
		int(rec.money),
		int(rec.last_spawn_id),
		int(rec.pending_level_id),
		int(rec.pending_spawn_id),
	]
