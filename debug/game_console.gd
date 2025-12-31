extends CanvasLayer

var _commands: Dictionary = {}
var _history: Array[String] = []
var _history_index: int = -1

@onready var log_display: RichTextLabel = %LogDisplay
@onready var input_field: LineEdit = %InputField
@onready var container: Control = %ConsoleContainer

func _ready() -> void:
	if not OS.is_debug_build():
		set_process_input(false)
		queue_free()
		return

	container.visible = false
	register_command("help", _cmd_help, "Shows this help message")
	register_command("clear", _cmd_clear, "Clears the console log")
	register_command("quit", _cmd_quit, "Quits the game")
	register_command("give", _cmd_give, "Usage: give <item_id> [amount]")
	register_command("time", _cmd_time, "Usage: time [skip|scale <float>]")
	register_command("save", _cmd_save, "Save the game")
	register_command("load", _cmd_load, "Load the game")
	register_command("continue", _cmd_continue, "Continue from session (autosave)")
	register_command("save_slot", _cmd_save_slot, "Usage: save_slot <slot>")
	register_command("load_slot", _cmd_load_slot, "Usage: load_slot <slot>")
	register_command("slots", _cmd_slots, "List save slots")
	register_command("travel", _cmd_travel, "Usage: travel <level_id>")
	register_command("agents", _cmd_agents, "Usage: agents [level_id] (prints AgentRegistry)")
	register_command(
		"npc_spawn",
		_cmd_npc_spawn,
		"Usage: npc_spawn <agent_id> [spawn_id] [level_id] (spawns/updates an NPC + syncs)"
	)
	register_command(
		"npc_schedule_dump",
		_cmd_npc_schedule_dump,
		"Usage: npc_schedule_dump <npc_id> (prints schedule steps if configured)"
	)
	register_command(
		"save_dump",
		_cmd_save_dump,
		"Usage: save_dump session|slot <name> (prints save summaries)"
	)
	register_command(
		"save_dump_agents",
		_cmd_save_dump_agents,
		"Usage: save_dump_agents session|slot <name> (prints AgentRecords)"
	)
	register_command(
		"save_dump_levels",
		_cmd_save_dump_levels,
		"Usage: save_dump_levels session|slot <name> (lists LevelSave ids)"
	)
	# Manually handle input to avoid focus loss issues
	# We removed the signal in the scene, so we just connect GUI input here
	input_field.gui_input.connect(_on_input_field_gui_input)
	print_line("Welcome to the Farming Game Debug Console. Type 'help' for commands.")

func _on_input_field_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_input_submitted(input_field.text)
		input_field.accept_event() # Prevent default behavior (which might be losing focus)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_APOSTROPHE:
			toggle_console()
			get_viewport().set_input_as_handled()
		elif container.visible:
			if event.keycode == KEY_UP:
				_navigate_history(1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				_navigate_history(-1)
				get_viewport().set_input_as_handled()

func toggle_console() -> void:
	container.visible = not container.visible
	if container.visible:
		input_field.grab_focus()
		get_tree().paused = true
	else:
		input_field.release_focus()
		get_tree().paused = false

func register_command(cmd: String, callable: Callable, description: String = "") -> void:
	_commands[cmd] = {
		"func": callable,
		"desc": description
	}

func print_line(text: String, color: String = "white") -> void:
	log_display.push_color(Color(color))
	log_display.add_text(text + "\n")
	log_display.pop()

func _on_input_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		_refocus_input()
		return

	input_field.clear()
	print_line("> " + text, "gray")
	_history.append(text)
	_history_index = -1
	var parts = text.split(" ", false)
	var cmd_name = parts[0]
	var args = parts.slice(1)

	if _commands.has(cmd_name):
		var cmd = _commands[cmd_name]
		cmd["func"].call(args)
	else:
		print_line("Unknown command: " + cmd_name, "red")
	_refocus_input()

func _refocus_input() -> void:
	input_field.call_deferred("grab_focus")

func _navigate_history(off: int) -> void:
	if _history.is_empty():
		return

	if _history_index == -1:
		_history_index = _history.size()

	_history_index = clamp(_history_index - off, 0, _history.size())

	if _history_index == _history.size():
		input_field.text = ""
	else:
		input_field.text = _history[_history_index]
		input_field.caret_column = input_field.text.length()

# --- Built-in Commands ---

func _cmd_help(_args: Array) -> void:
	print_line("--- Available Commands ---", "yellow")
	for cmd in _commands:
		print_line(cmd + ": " + _commands[cmd]["desc"])

func _cmd_clear(_args: Array) -> void:
	log_display.clear()

func _cmd_quit(_args: Array) -> void:
	get_tree().quit()

func _cmd_give(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: give <item_id> [amount]", "yellow")
		return

	var item_id = args[0]
	var amount = 1
	if args.size() > 1:
		amount = int(args[1])

	var player = get_tree().get_first_node_in_group(Groups.PLAYER)
	if not player:
		print_line("Error: Player not found. Is the scene loaded?", "red")
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
		print_line("Error: Could not find item resource for '%s'" % item_id, "red")
		return

	var leftover = player.inventory.add_item(item_data, amount)
	if leftover == 0:
		print_line(str("Gave %d x %s" % [amount, item_data.display_name]), "green")
	else:
		print_line(
			str("Gave %d x %s (Inventory full!)") % [amount - leftover, item_data.display_name],
            "yellow"
		)

func _cmd_time(args: Array) -> void:
	if args.is_empty():
		var day = str(TimeManager.current_day) if TimeManager else "?"
		var tod := "?"
		if TimeManager:
			tod = "%02d:%02d" % [int(TimeManager.get_hour()), int(TimeManager.get_minute())]
		print_line(str("Current Day: %s  Time: %s") % [day, tod])
		return

	var sub = args[0]
	if sub == "skip":
		if TimeManager:
			TimeManager.advance_day()
			print_line("Skipped to Day %d" % TimeManager.current_day, "green")
	elif sub == "set_minute":
		if TimeManager == null:
			return
		if args.size() < 2:
			print_line("Usage: time set_minute <0-1439>", "yellow")
			return
		var m := int(args[1])
		TimeManager.set_minute_of_day(m)
		print_line(
			"Time set to %02d:%02d" % [int(TimeManager.get_hour()), int(TimeManager.get_minute())],
			"green"
		)
	elif sub == "scale":
		if args.size() > 1:
			var s = float(args[1])
			Engine.time_scale = s
			print_line("Time scale: %.2f" % s)
		else:
			print_line("Current time scale: %.2f" % Engine.time_scale)

func _cmd_save(_args: Array) -> void:
	if GameManager != null and GameManager.save_to_slot("default"):
		print_line("Game saved successfully.", "green")
	else:
		print_line("Failed to save game.", "red")

func _cmd_load(_args: Array) -> void:
	var success = false
	if GameManager != null:
		success = await GameManager.load_from_slot("default")
	if success:
		print_line("Game loaded successfully.", "green")
	else:
		print_line("Failed to load game.", "red")

func _cmd_continue(_args: Array) -> void:
	var success = false
	if GameManager != null:
		success = await GameManager.continue_session()
	if success:
		print_line("Continued session successfully.", "green")
	else:
		print_line("Failed to continue session.", "red")

func _cmd_save_slot(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: save_slot <slot>", "yellow")
		return
	var slot := String(args[0])
	if GameManager != null and GameManager.save_to_slot(slot):
		print_line("Saved slot '%s'." % slot, "green")
	else:
		print_line("Failed to save slot '%s'." % slot, "red")

func _cmd_load_slot(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: load_slot <slot>", "yellow")
		return
	var slot := String(args[0])
	var success = false
	if GameManager != null:
		success = await GameManager.load_from_slot(slot)
	if success:
		print_line("Loaded slot '%s'." % slot, "green")
	else:
		print_line("Failed to load slot '%s'." % slot, "red")

func _cmd_travel(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: travel <level_id>", "yellow")
		return
	var level_id := StringName(String(args[0]))
	if GameManager == null:
		print_line("Error: GameManager not found.", "red")
		return
	var ok: bool = await GameManager.travel_to_level(Enums.Levels.get(level_id))
	if ok:
		print_line("Traveled to '%s'." % String(level_id), "green")
	else:
		print_line("Failed to travel to '%s'." % String(level_id), "red")

func _cmd_slots(_args: Array) -> void:
	if SaveManager == null:
		print_line("Error: SaveManager not found.", "red")
		return
	var slots := SaveManager.list_slots()
	if slots.is_empty():
		print_line("(no slots)", "yellow")
		return
	print_line("--- Slots ---", "yellow")
	for s in slots:
		var t := int(SaveManager.get_slot_modified_unix(s))
		print_line("%s (mtime=%d)" % [s, t], "white")

func _cmd_agents(args: Array) -> void:
	if AgentRegistry == null:
		print_line("Error: AgentRegistry not found.", "red")
		return

	var filter_level: int = -1
	if not args.is_empty() and String(args[0]).is_valid_int():
		filter_level = int(args[0])

	var agents: Dictionary = AgentRegistry.debug_get_agents()
	if agents.is_empty():
		print_line("(no agents)", "yellow")
		return

	print_line("--- Agents ---", "yellow")
	for agent_id in agents:
		var rec: AgentRecord = agents[agent_id] as AgentRecord
		if rec == null:
			continue
		if filter_level != -1 and int(rec.current_level_id) != filter_level:
			continue

		print_line(
			"%s kind=%s level=%s cell=%s pending=(%s,%s)" % [
				String(rec.agent_id),
				str(int(rec.kind)),
				str(int(rec.current_level_id)),
				str(rec.last_cell),
				str(int(rec.pending_level_id)),
				str(int(rec.pending_spawn_id)),
			],
			"white"
		)

func _cmd_npc_spawn(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: npc_spawn <agent_id> [spawn_id] [level_id]", "yellow")
		return
	if AgentRegistry == null or AgentSpawner == null:
		print_line("Error: AgentRegistry/AgentSpawner not found.", "red")
		return
	if GameManager == null:
		print_line("Error: GameManager not found.", "red")
		return

	var agent_id := StringName(String(args[0]))
	if String(agent_id).is_empty():
		print_line("Error: agent_id cannot be empty.", "red")
		return

	var spawn_id: int = int(Enums.SpawnId.NONE)
	if args.size() >= 2:
		var raw := String(args[1])
		if raw.is_valid_int():
			spawn_id = int(raw)
		else:
			spawn_id = int(Enums.SpawnId.get(raw, int(Enums.SpawnId.NONE)))

	var level_id: int = int(GameManager.get_active_level_id())
	if args.size() >= 3:
		var raw_level := String(args[2])
		if raw_level.is_valid_int():
			level_id = int(raw_level)
		else:
			level_id = int(Enums.Levels.get(raw_level, level_id))

	var rec: AgentRecord = AgentRegistry.get_record(agent_id) as AgentRecord
	if rec == null:
		rec = AgentRecord.new()
		rec.agent_id = agent_id

	rec.kind = Enums.AgentKind.NPC
	rec.current_level_id = level_id as Enums.Levels
	# Enums in GDScript are ints; keep it simple.
	rec.last_spawn_id = spawn_id as Enums.SpawnId
	# Provide a reasonable initial position even if a spawn marker is missing.
	if SpawnManager != null and spawn_id != int(Enums.SpawnId.NONE):
		var lr := GameManager.get_active_level_root()
		rec.last_world_pos = SpawnManager.get_spawn_pos(lr, rec.last_spawn_id)
	else:
		rec.last_world_pos = Vector2.ZERO

	AgentRegistry.upsert_record(rec)
	AgentRegistry.save_to_session()
	AgentSpawner.sync_agents_for_active_level()
	print_line(
		"Spawned/updated NPC '%s' (level=%d spawn_id=%d)." % [
			String(agent_id),
			int(level_id),
			int(rec.last_spawn_id),
		],
		"green"
	)

func _cmd_npc_schedule_dump(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: npc_schedule_dump <npc_id>", "yellow")
		return
	if AgentRegistry == null:
		print_line("Error: AgentRegistry not found.", "red")
		return

	var npc_id := StringName(String(args[0]))
	var rec := AgentRegistry.get_record(npc_id) as AgentRecord
	if rec == null:
		print_line("No AgentRecord for npc_id=%s" % String(npc_id), "yellow")
	else:
		print_line("Record: %s" % _format_agent_record(rec), "white")

	# Prefer runtime NPC node (schedule is stored in NpcConfig).
	for n in get_tree().get_nodes_in_group(Groups.AGENT_COMPONENTS):
		if not (n is AgentComponent):
			continue
		var ac := n as AgentComponent
		if ac.agent_id != npc_id:
			continue

		var host := ac.get_parent()
		if host != null and host.name == "Components":
			host = host.get_parent()
		if not (host is NPC):
			continue
		var npc := host as NPC
		if npc.npc_config == null or npc.npc_config.schedule == null:
			print_line("NPC %s has no schedule." % String(npc_id), "yellow")
			return

		var sched: Resource = npc.npc_config.schedule
		if not ("steps" in sched):
			print_line("Schedule resource has no 'steps' field.", "red")
			return

		print_line("--- Schedule: %s ---" % String(npc_id), "yellow")
		var steps: Array = sched.get("steps") as Array
		for i in range(steps.size()):
			var step: Resource = steps[i] as Resource
			if step == null or not is_instance_valid(step):
				continue
			var kind := int(step.get("kind")) if ("kind" in step) else -1
			var start := int(step.get("start_minute_of_day")) if ("start_minute_of_day" in step) else -1
			var dur := int(step.get("duration_minutes")) if ("duration_minutes" in step) else -1
			var lvl := int(step.get("level_id")) if ("level_id" in step) else -1
			var route := int(step.get("route_id")) if ("route_id" in step) else -1
			var tlvl := int(step.get("target_level_id")) if ("target_level_id" in step) else -1
			var tspawn := int(step.get("target_spawn_id")) if ("target_spawn_id" in step) else -1

			print_line(
				"[%d] kind=%d start=%d dur=%d lvl=%d route=%d travel=(%d,%d)" % [
					i, kind, start, dur, lvl, route, tlvl, tspawn
				],
				"white"
			)
		return

	print_line("NPC %s is not currently spawned in this level." % String(npc_id), "yellow")

func _cmd_save_dump(args: Array) -> void:
	if SaveManager == null:
		print_line("Error: SaveManager not found.", "red")
		return
	if args.size() < 1:
		print_line("Usage: save_dump session|slot <name>", "yellow")
		return

	var scope := String(args[0])
	var scope_name := String(args[1]) if args.size() > 1 else ""

	if scope == "session":
		_dump_session_summary()
		return
	if scope == "slot":
		if scope_name.is_empty():
			print_line("Usage: save_dump slot <slot_name>", "yellow")
			return
		_dump_slot_summary(scope_name)
		return

	print_line("Usage: save_dump session|slot <name>", "yellow")

func _cmd_save_dump_agents(args: Array) -> void:
	if SaveManager == null:
		print_line("Error: SaveManager not found.", "red")
		return
	if args.size() < 1:
		print_line("Usage: save_dump_agents session|slot <name>", "yellow")
		return

	var scope := String(args[0])
	var scope_name := String(args[1]) if args.size() > 1 else ""

	var a: AgentsSave = null
	if scope == "session":
		a = SaveManager.load_session_agents_save()
	elif scope == "slot":
		if scope_name.is_empty():
			print_line("Usage: save_dump_agents slot <slot_name>", "yellow")
			return
		a = SaveManager.load_slot_agents_save(scope_name)
	else:
		print_line("Usage: save_dump_agents session|slot <name>", "yellow")
		return

	if a == null:
		print_line("(no agents save)", "yellow")
		return

	print_line("--- AgentsSave ---", "yellow")
	print_line("agents=%d" % a.agents.size(), "white")
	for rec in a.agents:
		if rec == null:
			continue
		print_line(_format_agent_record(rec), "white")

func _cmd_save_dump_levels(args: Array) -> void:
	if SaveManager == null:
		print_line("Error: SaveManager not found.", "red")
		return
	if args.size() < 1:
		print_line("Usage: save_dump_levels session|slot <name>", "yellow")
		return

	var scope := String(args[0])
	var scope_name := String(args[1]) if args.size() > 1 else ""

	var level_ids: Array[Enums.Levels] = []
	if scope == "session":
		level_ids = SaveManager.list_session_level_ids()
	elif scope == "slot":
		if scope_name.is_empty():
			print_line("Usage: save_dump_levels slot <slot_name>", "yellow")
			return
		level_ids = SaveManager.list_slot_level_ids(scope_name)
	else:
		print_line("Usage: save_dump_levels session|slot <name>", "yellow")
		return

	if level_ids.is_empty():
		print_line("(no level saves)", "yellow")
		return

	print_line("--- LevelSaves ---", "yellow")
	for lid in level_ids:
		print_line("level_id=%s" % str(int(lid)), "white")

func _dump_session_summary() -> void:
	var gs := SaveManager.load_session_game_save()
	var a := SaveManager.load_session_agents_save()
	var levels := SaveManager.list_session_level_ids()

	print_line("--- Session Save Summary ---", "yellow")
	if gs == null:
		print_line("GameSave: (missing)", "yellow")
	else:
		print_line(
			"GameSave: day=%d active_level_id=%d" % [int(gs.current_day), int(gs.active_level_id)],
			"white"
		)
	if a == null:
		print_line("AgentsSave: (missing)", "yellow")
	else:
		print_line("AgentsSave: agents=%d" % a.agents.size(), "white")
	print_line("LevelSaves: %d" % levels.size(), "white")

func _dump_slot_summary(slot: String) -> void:
	var gs := SaveManager.load_slot_game_save(slot)
	var a := SaveManager.load_slot_agents_save(slot)
	var levels := SaveManager.list_slot_level_ids(slot)

	print_line("--- Slot Save Summary: %s ---" % slot, "yellow")
	if gs == null:
		print_line("GameSave: (missing)", "yellow")
	else:
		print_line(
			"GameSave: day=%d active_level_id=%d" % [int(gs.current_day), int(gs.active_level_id)],
			"white"
		)
	if a == null:
		print_line("AgentsSave: (missing)", "yellow")
	else:
		print_line("AgentsSave: agents=%d" % a.agents.size(), "white")
	print_line("LevelSaves: %d" % levels.size(), "white")

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
