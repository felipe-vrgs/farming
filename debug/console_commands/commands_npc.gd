class_name CommandsNPC
extends ConsoleCommandModule

func get_category() -> String:
	return "NPC/Agents"

func _register_commands() -> void:
	_cmd("agents", _cmd_agents, "Usage: agents [level_id] (prints AgentRegistry)")
	_cmd("npc_spawn",
		_cmd_npc_spawn,
		"Usage: npc_spawn <agent_id> <spawn_point_path> (spawns/updates an NPC + syncs)"
	)
	_cmd("npc_schedule_dump",
		_cmd_npc_schedule_dump,
		"Usage: npc_schedule_dump <npc_id> (prints schedule steps if configured)"
	)
	_cmd("npc_travel",
		_cmd_npc_travel,
		"Usage: npc_travel <agent_id> <spawn_point_path> [deadline_rel_mins]"
	)
	_cmd("npc_travel_intent",
		_cmd_npc_travel_intent,
		"Usage: npc_travel_intent <agent_id> (print pending + deadline)"
	)

func _cmd_agents(args: Array) -> void:
	if AgentRegistry == null:
		_print("Error: AgentRegistry not found.", "red")
		return

	var filter_level: int = -1
	if not args.is_empty() and String(args[0]).is_valid_int():
		filter_level = int(args[0])

	var agents: Dictionary = AgentRegistry.debug_get_agents()
	if agents.is_empty():
		_print("(no agents)", "yellow")
		return

	_print("--- Agents ---", "yellow")
	for agent_id in agents:
		var rec: AgentRecord = agents[agent_id] as AgentRecord
		if rec == null:
			continue
		if filter_level != -1 and int(rec.current_level_id) != filter_level:
			continue

		_print(
			"%s kind=%s level=%s spawn=%s pos=%s cell=%s pending=(%s,%s)" % [
				String(rec.agent_id),
				str(int(rec.kind)),
				str(int(rec.current_level_id)),
				_short_path(rec.last_spawn_point_path),
				str(rec.last_world_pos),
				str(rec.last_cell),
				str(int(rec.pending_level_id)),
				_short_path(rec.pending_spawn_point_path),
			],
			"white"
		)

func _cmd_npc_spawn(args: Array) -> void:
	if args.size() < 2:
		_print("Usage: npc_spawn <agent_id> <spawn_point_path>", "yellow")
		_print("Example: npc_spawn frieren res://data/spawn_points/island/player_spawn.tres", "yellow")
		return
	if AgentRegistry == null or AgentSpawner == null:
		_print("Error: AgentRegistry/AgentSpawner not found.", "red")
		return
	if GameManager == null:
		_print("Error: GameManager not found.", "red")
		return

	var agent_id := StringName(String(args[0]))
	if String(agent_id).is_empty():
		_print("Error: agent_id cannot be empty.", "red")
		return

	var spawn_path := String(args[1])
	var spawn_point: SpawnPointData = null
	if not spawn_path.is_empty() and ResourceLoader.exists(spawn_path):
		spawn_point = load(spawn_path) as SpawnPointData

	if spawn_point == null or not spawn_point.is_valid():
		_print("Error: Invalid spawn point path: %s" % spawn_path, "red")
		return

	var rec: AgentRecord = AgentRegistry.get_record(agent_id) as AgentRecord
	if rec == null:
		rec = AgentRecord.new()
		rec.agent_id = agent_id

	rec.kind = Enums.AgentKind.NPC
	rec.current_level_id = spawn_point.level_id
	rec.last_spawn_point_path = spawn_point.resource_path
	rec.last_world_pos = spawn_point.position

	AgentRegistry.upsert_record(rec)
	AgentRegistry.save_to_session()
	AgentSpawner.sync_agents_for_active_level()
	_print(
		"Spawned/updated NPC '%s' (level=%d spawn=%s)." % [
			String(agent_id),
			int(spawn_point.level_id),
			_short_path(spawn_point.resource_path),
		],
		"green"
	)

func _cmd_npc_schedule_dump(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: npc_schedule_dump <npc_id>", "yellow")
		return
	if AgentRegistry == null:
		_print("Error: AgentRegistry not found.", "red")
		return

	var npc_id := StringName(String(args[0]))
	var rec := AgentRegistry.get_record(npc_id) as AgentRecord
	if rec == null:
		_print("No AgentRecord for npc_id=%s" % String(npc_id), "yellow")
	else:
		_print("Record: %s" % _format_agent_record(rec), "white")

	var nodes = _console.get_tree().get_nodes_in_group(Groups.AGENT_COMPONENTS)
	for n in nodes:
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
			_print("NPC %s has no schedule." % String(npc_id), "yellow")
			return

		var sched: Resource = npc.npc_config.schedule
		if not ("steps" in sched):
			_print("Schedule resource has no 'steps' field.", "red")
			return

		_print("--- Schedule: %s ---" % String(npc_id), "yellow")
		var steps: Array = sched.get("steps") as Array
		for i in range(steps.size()):
			var step: Resource = steps[i] as Resource
			if step == null or not is_instance_valid(step):
				continue
			var kind := int(step.get("kind")) if ("kind" in step) else -1
			var start := int(step.get("start_minute_of_day")) if ("start_minute_of_day" in step) else -1
			var dur := int(step.get("duration_minutes")) if ("duration_minutes" in step) else -1
			var lvl := int(step.get("level_id")) if ("level_id" in step) else -1
			var route_path := ""
			if ("route_res" in step) and (step.get("route_res") is Resource):
				route_path = String((step.get("route_res") as Resource).resource_path)
			var spawn_path := ""
			if ("target_spawn_point" in step) and (step.get("target_spawn_point") is SpawnPointData):
				spawn_path = String((step.get("target_spawn_point") as SpawnPointData).resource_path)

			_print(
				"[%d] kind=%d start=%d dur=%d lvl=%d route=%s spawn=%s" % [
					i, kind, start, dur, lvl, _short_path(route_path), _short_path(spawn_path)
				],
				"white"
			)
		return

	_print("NPC %s is not currently spawned in this level." % String(npc_id), "yellow")

func _cmd_npc_travel(args: Array) -> void:
	if args.size() < 2:
		_print("Usage: npc_travel <agent_id> <spawn_point_path> [deadline_rel_mins]", "yellow")
		_print("Example: npc_travel frieren res://data/spawn_points/island/player_spawn.tres 5", "yellow")
		return

	var agent_id := StringName(String(args[0]))
	var spawn_path := String(args[1])

	var spawn_point: SpawnPointData = null
	if not spawn_path.is_empty() and ResourceLoader.exists(spawn_path):
		spawn_point = load(spawn_path) as SpawnPointData

	if spawn_point == null or not spawn_point.is_valid():
		_print("Error: Invalid spawn point path: %s" % spawn_path, "red")
		return

	var deadline_rel: int = 5
	if args.size() >= 3:
		deadline_rel = int(args[2])

	var deadline_abs := -1
	if TimeManager != null:
		deadline_abs = int(TimeManager.get_absolute_minute()) + deadline_rel
	else:
		_print("TimeManager missing, cannot set deadline.", "yellow")

	if AgentRegistry != null:
		AgentRegistry.set_travel_intent(agent_id, spawn_point, deadline_abs)
		_print(
			"Set travel intent: %s -> %s deadline=%d" % [
				agent_id,
				_short_path(spawn_point.resource_path),
				deadline_abs,
			],
			"green"
		)
	else:
		_print("AgentRegistry not found.", "red")

func _cmd_npc_travel_intent(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: npc_travel_intent <agent_id>", "yellow")
		return

	var agent_id := StringName(String(args[0]))
	if AgentRegistry == null:
		_print("AgentRegistry not found.", "red")
		return

	var rec := AgentRegistry.get_record(agent_id) as AgentRecord
	if rec == null:
		_print("Agent not found: %s" % agent_id, "yellow")
		return

	_print("Travel Intent for %s:" % agent_id, "yellow")
	_print("  Pending Level: %d" % int(rec.pending_level_id), "white")
	_print("  Pending Spawn: %s" % _short_path(rec.pending_spawn_point_path), "white")
	var now := -1
	if TimeManager != null:
		now = int(TimeManager.get_absolute_minute())
	_print("  Expires Abs: %d (now=%d)" % [int(rec.pending_expires_absolute_minute), now], "white")

func _format_agent_record(rec: AgentRecord) -> String:
	return "%s kind=%d level=%d pos=%s cell=%s money=%d spawn=%s pending=(%d,%s)" % [
		String(rec.agent_id),
		int(rec.kind),
		int(rec.current_level_id),
		str(rec.last_world_pos),
		str(rec.last_cell),
		int(rec.money),
		_short_path(rec.last_spawn_point_path),
		int(rec.pending_level_id),
		_short_path(rec.pending_spawn_point_path),
	]

func _short_path(path: String) -> String:
	if path.is_empty():
		return "(none)"
	return path.get_file().get_basename()
