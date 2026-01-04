class_name CommandsNPC
extends ConsoleCommandModule


func get_category() -> String:
	return "NPC/Agents"


func _register_commands() -> void:
	_cmd("agents", _cmd_agents, "Usage: agents [level_id] (prints AgentRegistry)")
	_cmd(
		"npc_schedule_dump",
		_cmd_npc_schedule_dump,
		"Usage: npc_schedule_dump <npc_id> (prints schedule steps if configured)"
	)


func _cmd_agents(args: Array) -> void:
	if AgentBrain.registry == null:
		_print("Error: AgentRegistry not found.", "red")
		return

	var filter_level: int = -1
	if not args.is_empty() and String(args[0]).is_valid_int():
		filter_level = int(args[0])

	var agents: Dictionary = AgentBrain.registry.debug_get_agents()
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
			(
				"%s kind=%s level=%s spawn=%s pos=%s cell=%s"
				% [
					String(rec.agent_id),
					str(int(rec.kind)),
					str(int(rec.current_level_id)),
					_short_path(rec.last_spawn_point_path),
					str(rec.last_world_pos),
					str(rec.last_cell)
				]
			),
			"white"
		)


func _cmd_npc_schedule_dump(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: npc_schedule_dump <npc_id>", "yellow")
		return
	if AgentBrain.registry == null:
		_print("Error: AgentRegistry not found.", "red")
		return

	var npc_id := StringName(String(args[0]))
	var rec := AgentBrain.registry.get_record(npc_id) as AgentRecord
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
			var start := (
				int(step.get("start_minute_of_day")) if ("start_minute_of_day" in step) else -1
			)
			var dur := int(step.get("duration_minutes")) if ("duration_minutes" in step) else -1
			var lvl := int(step.get("level_id")) if ("level_id" in step) else -1
			var route_path := ""
			if ("route_res" in step) and (step.get("route_res") is Resource):
				route_path = String((step.get("route_res") as Resource).resource_path)
			var spawn_path := ""
			if (
				("target_spawn_point" in step)
				and (step.get("target_spawn_point") is SpawnPointData)
			):
				spawn_path = String(
					(step.get("target_spawn_point") as SpawnPointData).resource_path
				)

			_print(
				(
					"[%d] kind=%d start=%d dur=%d lvl=%d route=%s spawn=%s"
					% [i, kind, start, dur, lvl, _short_path(route_path), _short_path(spawn_path)]
				),
				"white"
			)
		return

	_print("NPC %s is not currently spawned in this level." % String(npc_id), "yellow")


func _format_agent_record(rec: AgentRecord) -> String:
	return (
		"%s kind=%d level=%d pos=%s cell=%s money=%d spawn=%s"
		% [
			String(rec.agent_id),
			int(rec.kind),
			int(rec.current_level_id),
			str(rec.last_world_pos),
			str(rec.last_cell),
			int(rec.money),
			_short_path(rec.last_spawn_point_path)
		]
	)


func _short_path(path: String) -> String:
	if path.is_empty():
		return "(none)"
	return path.get_file().get_basename()
