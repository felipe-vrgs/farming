extends Node

## Dialogue/Cutscene manager (addon-agnostic facade).
## - Receives EventBus dialogue/cutscene start requests
## - Switches Runtime flow state (RUNNING / DIALOGUE / CUTSCENE)
## - Starts Dialogic timelines
## - Provides state capture/hydration for save system

signal dialogue_started(timeline_id: StringName)
signal dialogue_ended(timeline_id: StringName)

const TIMELINES_ROOT := "res://globals/dialogue/timelines/"

var _active: bool = false
var _dialogic: Node = null
var _current_timeline_id: StringName = &""
var _layout_node: Node = null
var _pending_hydrate: DialogueSave = null

## When chaining dialogue -> cutscene, Dialogic's built-in `dialog_ending_timeline`
## can introduce an extra timeline (and style/layout work) between them.
## We temporarily suppress it to reduce transition delay.
var _saved_dialogic_ending_timeline: Variant = null
var _suppress_dialogic_ending_timeline_depth: int = 0

## If a cutscene is requested while a dialogue timeline is active, we queue it and
## start it as soon as the dialogue ends.
var _queued_timeline_id: StringName = &""
var _queued_mode: Enums.FlowState = Enums.FlowState.RUNNING

## Best-effort "return cutscene agents to their pre-cutscene state".
## StringName agent_id -> AgentRecord snapshot (duplicated).
var _cutscene_agent_snapshots: Dictionary[StringName, AgentRecord] = {}

func _ready() -> void:
	# Must keep running while SceneTree is paused (dialogue mode).
	process_mode = Node.PROCESS_MODE_ALWAYS

	if EventBus != null:
		if ("dialogue_start_requested" in EventBus
				and not EventBus.dialogue_start_requested.is_connected(_on_dialogue_start_requested)):
			EventBus.dialogue_start_requested.connect(_on_dialogue_start_requested)

		if ("cutscene_start_requested" in EventBus
				and not EventBus.cutscene_start_requested.is_connected(_on_cutscene_start_requested)):
			EventBus.cutscene_start_requested.connect(_on_cutscene_start_requested)
		if not EventBus.day_started.is_connected(_on_day_started):
			EventBus.day_started.connect(_on_day_started)

	_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic != null:
		_connect_dialogic_signals(_dialogic)
	# If Runtime loaded dialogue state before Dialogic was ready, apply now.
	if _pending_hydrate != null:
		var pending := _pending_hydrate
		_pending_hydrate = null
		hydrate_state(pending)


#region Public API

func start_cutscene(cutscene_id: StringName, agent: Node = null) -> void:
	_on_cutscene_start_requested(cutscene_id, agent)

func is_active() -> bool:
	return _active

func capture_state() -> DialogueSave:
	var save := DialogueSave.new()
	if _dialogic == null:
		_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic == null:
		return save

	# Dialogic variables are stored in Dialogic.current_state_info['variables'] (Dictionary).
	if "current_state_info" in _dialogic:
		var csi = _dialogic.get("current_state_info")
		if csi is Dictionary and csi.has("variables") and csi["variables"] is Dictionary:
			save.dialogic_variables = (csi["variables"] as Dictionary).duplicate(true)

	return save

func hydrate_state(save: DialogueSave) -> void:
	if save == null:
		return
	if _dialogic == null:
		_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic == null:
		# Dialogic not ready yet (common during boot). Defer once.
		_pending_hydrate = save
		return

	# Overwrite dialogic variable state. Dialogic will merge defaults on its own load_game_state.
	if "current_state_info" in _dialogic:
		var csi = _dialogic.get("current_state_info")
		if csi is Dictionary:
			csi["variables"] = save.dialogic_variables.duplicate(true)

	if OS.is_debug_build():
		print("DialogueManager: Hydrated state with ", save.dialogic_variables.size(), " variables")

#endregion


#region EventBus receivers

func _on_dialogue_start_requested(_agent: Node, npc: Node, dialogue_id: StringName) -> void:
	if _active:
		return

	var npc_id := _get_npc_id(npc)
	if String(npc_id).is_empty():
		push_warning("DialogueManager: Cannot start dialogue, npc_id is empty.")
		return
	if String(dialogue_id).is_empty():
		push_warning(
			"DialogueManager: Cannot start dialogue, dialogue_id is empty for npc '%s'."
			% String(npc_id)
		)
		return

	var timeline_id := StringName("npcs/" + String(npc_id) + "/" + String(dialogue_id))
	_start_timeline(timeline_id, Enums.FlowState.DIALOGUE)

func _on_cutscene_start_requested(cutscene_id: StringName, _agent: Node) -> void:
	if _active:
		# Allow dialogue -> cutscene transitions by queueing the cutscene while the
		# dialogue timeline is still active. The timeline should end itself with
		# [end_timeline], then we start the queued cutscene immediately.
		if String(_current_timeline_id).begins_with("npcs/"):
			_queued_timeline_id = StringName("cutscenes/" + String(cutscene_id))
			_queued_mode = Enums.FlowState.CUTSCENE
			_dbg_flow(
				"Queued cutscene '%s' while '%s' is active"
				% [String(_queued_timeline_id), String(_current_timeline_id)]
			)
			_begin_fast_dialogic_end()
			# Best-effort prewarm: preload the cutscene timeline while dialogue is still running.
			_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
			if _dialogic != null and _dialogic.has_method("preload_timeline"):
				_dialogic.call("preload_timeline", _resolve_timeline_path(_queued_timeline_id))
			return
		push_warning("DialogueManager: Cannot start cutscene, another timeline is already active.")
		return
	if String(cutscene_id).is_empty():
		push_warning("DialogueManager: Empty cutscene_id.")
		return
	var timeline_id := StringName("cutscenes/" + String(cutscene_id))
	_start_timeline(timeline_id, Enums.FlowState.CUTSCENE)

#endregion


#region Internal

func _start_timeline(timeline_id: StringName, mode: Enums.FlowState) -> void:
	if String(timeline_id).is_empty():
		push_warning("DialogueManager: Empty timeline_id, cannot start.")
		return

	_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic == null:
		push_warning("DialogueManager: Dialogic not found at /root/Dialogic.")
		return

	var timeline_path := _resolve_timeline_path(timeline_id)
	if not ResourceLoader.exists(timeline_path):
		push_warning("DialogueManager: Timeline not found: %s" % timeline_path)
		return

	_active = true
	_current_timeline_id = timeline_id
	_dbg_flow("Start timeline '%s' mode=%s" % [String(timeline_id), str(int(mode))])

	# Capture pre-cutscene positions/levels for cutscene agents so we can restore
	# them after the cutscene ends (best-effort).
	if mode == Enums.FlowState.CUTSCENE:
		_capture_cutscene_agent_snapshots()

	# Switch world-mode state first so the UI starts in the correct mode.
	if Runtime != null and Runtime.has_method("request_flow_state"):
		Runtime.request_flow_state(mode)

	# Ensure Dialogic keeps running when SceneTree is paused (dialogue mode).
	_dialogic.process_mode = Node.PROCESS_MODE_ALWAYS

	dialogue_started.emit(timeline_id)

	# Use Dialogic.start(path) to ensure a layout scene is present.
	# Cutscenes can contain text too, so they still need a layout to render dialogue.
	if _dialogic.has_method("start"):
		_layout_node = _dialogic.call("start", timeline_path)
		_apply_dialogic_layout_overrides(_layout_node)
		return

	push_warning("DialogueManager: Dialogic node found, but no start() method detected.")
	_cutscene_agent_snapshots.clear()
	var finished_id := _clear_active_timeline()
	# Return to RUNNING on failure.
	if Runtime != null and Runtime.has_method("request_flow_state"):
		Runtime.request_flow_state(Enums.FlowState.RUNNING)
	dialogue_ended.emit(finished_id)

func _clear_active_timeline() -> StringName:
	var finished_id := _current_timeline_id
	_current_timeline_id = &""
	_active = false
	_layout_node = null
	return finished_id

func _resolve_timeline_path(timeline_id: StringName) -> String:
	return TIMELINES_ROOT + String(timeline_id) + ".dtl"

func _get_npc_id(npc: Node) -> StringName:
	if npc == null:
		return &""
	# Preferred: agent_id from AgentComponent.
	if npc.has_method("get") and "agent_component" in npc:
		var ac = npc.get("agent_component")
		if ac != null and "agent_id" in ac:
			return ac.agent_id
	# Fallback: npc_id from npc_config.
	if npc.has_method("get") and "npc_config" in npc:
		var cfg = npc.get("npc_config")
		if cfg != null and "npc_id" in cfg:
			return cfg.npc_id
	return &""

func _connect_dialogic_signals(d: Node) -> void:
	var end_signal_names := [
		"timeline_ended",
		"timeline_finished",
		"dialogue_ended",
		"finished",
	]
	for s in end_signal_names:
		if d.has_signal(s) and not d.is_connected(s, _on_dialogue_finished):
			d.connect(s, _on_dialogue_finished)

func _on_dialogue_finished(_a = null, _b = null, _c = null) -> void:
	if not _active:
		return

	var finished_id := _clear_active_timeline()
	_dbg_flow("Timeline finished '%s'" % String(finished_id))
	# Track completion for branching/persistence via Dialogic variables.
	if not String(finished_id).is_empty():
		_mark_timeline_completed_in_dialogic_vars(finished_id)
	# Cutscene agent restores are explicit (performed by a Dialogic event in the timeline).
	# Clear any remaining snapshots when the cutscene ends.
	if String(finished_id).begins_with("cutscenes/"):
		_cutscene_agent_snapshots.clear()

	# If a cutscene was queued during dialogue, start it now (do not return to RUNNING in-between).
	var next_timeline_id := _queued_timeline_id
	var next_mode := _queued_mode
	_queued_timeline_id = &""
	_queued_mode = Enums.FlowState.RUNNING

	if not String(next_timeline_id).is_empty():
		_dbg_flow("Chaining to '%s' mode=%s" % [String(next_timeline_id), str(int(next_mode))])
		dialogue_ended.emit(finished_id)
		_start_timeline(next_timeline_id, next_mode)
		return

	# Return to RUNNING when the active timeline ends.
	if Runtime != null and Runtime.has_method("request_flow_state"):
		Runtime.request_flow_state(Enums.FlowState.RUNNING)
	_end_fast_dialogic_end()

	dialogue_ended.emit(finished_id)

func _dbg_flow(msg: String) -> void:
	if not OS.is_debug_build():
		return
	print("DialogueManager[%d]: %s" % [Time.get_ticks_msec(), msg])

func _mark_timeline_completed_in_dialogic_vars(timeline_id: StringName) -> void:
	_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic == null:
		return
	if "current_state_info" not in _dialogic:
		return
	var csi = _dialogic.get("current_state_info")
	if not (csi is Dictionary):
		return
	if not csi.has("variables") or not (csi["variables"] is Dictionary):
		return

	var vars: Dictionary = csi["variables"]
	if not vars.has("completed_timelines") or not (vars["completed_timelines"] is Dictionary):
		vars["completed_timelines"] = {}

	var segments := String(timeline_id).split("/", false)
	if segments.is_empty():
		return
	_set_nested_bool(vars["completed_timelines"] as Dictionary, segments, true)

func _set_nested_bool(root: Dictionary, segments: Array[String], value: bool) -> void:
	if root == null or segments.is_empty():
		return
	var d := root
	for i in range(segments.size()):
		var k := segments[i]
		if k.is_empty():
			continue
		var is_last := i == segments.size() - 1
		if is_last:
			d[k] = value
			return
		if not d.has(k) or not (d[k] is Dictionary):
			d[k] = {}
		d = d[k] as Dictionary

func _begin_fast_dialogic_end() -> void:
	_suppress_dialogic_ending_timeline_depth += 1
	if _suppress_dialogic_ending_timeline_depth != 1:
		return
	_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic == null:
		return
	if _saved_dialogic_ending_timeline == null and "dialog_ending_timeline" in _dialogic:
		_saved_dialogic_ending_timeline = _dialogic.get("dialog_ending_timeline")
	# Disable the ending timeline so end_timeline() doesn't run an extra timeline in-between.
	if "dialog_ending_timeline" in _dialogic:
		_dialogic.set("dialog_ending_timeline", null)

func _end_fast_dialogic_end() -> void:
	_suppress_dialogic_ending_timeline_depth = max(0, _suppress_dialogic_ending_timeline_depth - 1)
	if _suppress_dialogic_ending_timeline_depth != 0:
		return
	_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic == null:
		return
	if _saved_dialogic_ending_timeline != null and "dialog_ending_timeline" in _dialogic:
		_dialogic.set("dialog_ending_timeline", _saved_dialogic_ending_timeline)
	_saved_dialogic_ending_timeline = null

func _on_day_started(_day_index: int) -> void:
	reset_daily_flags()

func reset_daily_flags() -> void:
	if _dialogic == null:
		return
	if "current_state_info" not in _dialogic:
		return
	var csi = _dialogic.get("current_state_info")
	if not (csi is Dictionary) or not csi.has("variables") or not (csi["variables"] is Dictionary):
		return

	var root_vars: Dictionary = csi["variables"]
	_reset_daily_flags_in_dict(root_vars)

func _reset_daily_flags_in_dict(d: Dictionary) -> void:
	for k in d.keys():
		var v = d[k]
		if v is Dictionary:
			_reset_daily_flags_in_dict(v)
			continue
		# Convention: any variable key ending in "_today" resets to false.
		if String(k).ends_with("_today"):
			d[k] = false

func _apply_dialogic_layout_overrides(layout: Node) -> void:
	# Keep the dialog UI running if SceneTree is paused.
	# Layout sizing should be handled by Dialogic styles (see dialogic/layout/default_style).
	if layout == null or not is_instance_valid(layout):
		return

	layout.process_mode = Node.PROCESS_MODE_ALWAYS

func _capture_cutscene_agent_snapshots() -> void:
	_cutscene_agent_snapshots.clear()

	# Capture best-effort authoritative records for cutscene agents.
	if AgentBrain != null and AgentBrain.spawner != null:
		AgentBrain.spawner.capture_spawned_agents()

	if AgentBrain == null or AgentBrain.registry == null:
		return

	# Snapshot player (if present) and Frieren (default cutscene agent).
	# We keep snapshots only for explicit restoration events in the cutscene timeline.
	var player_id := _find_player_agent_id()
	if not String(player_id).is_empty():
		var prec = AgentBrain.registry.get_record(player_id)
		if prec is AgentRecord:
			_cutscene_agent_snapshots[player_id] = (prec as AgentRecord).duplicate(true)

	var frieren_id: StringName = &"frieren"
	var frec = AgentBrain.registry.get_record(frieren_id)
	if frec is AgentRecord:
		_cutscene_agent_snapshots[frieren_id] = (frec as AgentRecord).duplicate(true)

func restore_cutscene_agent_snapshot(agent_id: StringName) -> void:
	# Explicit restoration hook for cutscene timelines (called by Dialogic events).
	if String(agent_id).is_empty():
		return
	if AgentBrain == null or AgentBrain.registry == null:
		return

	# Map "player" to the actual player record id (some saves use dynamic ids).
	var effective_id := agent_id
	if agent_id == &"player":
		var pid := _find_player_agent_id()
		if String(pid).is_empty():
			return
		effective_id = pid

	var snap: AgentRecord = _cutscene_agent_snapshots.get(effective_id) as AgentRecord
	if snap == null:
		return

	# Restore record (duplicate so we don't keep a live reference).
	AgentBrain.registry.upsert_record(snap.duplicate(true))

	# If restoring the player and the snapshot is in a different level, we must
	# actually change the active level scene; syncing alone won't swap scenes.
	if agent_id == &"player" and Runtime != null and Runtime.has_method("get_active_level_id"):
		var target_level: Enums.Levels = snap.current_level_id
		var active_level: Enums.Levels = Runtime.get_active_level_id()
		if target_level != Enums.Levels.NONE and target_level != active_level:
			# Use an in-memory spawn point so the player lands exactly at the snapshot position.
			var sp := SpawnPointData.new()
			sp.level_id = target_level
			sp.position = snap.last_world_pos
			await Runtime.perform_level_change(target_level, sp)

	# Sync spawns for the active level so level membership changes are respected.
	if AgentBrain.spawner != null and Runtime != null and Runtime.has_method("get_active_level_root"):
		var lr := Runtime.get_active_level_root()
		if lr != null:
			AgentBrain.spawner.sync_agents_for_active_level(lr)

	# If agent exists in the current scene, apply position immediately.
	if Runtime != null and Runtime.has_method("find_agent_by_id"):
		var node := Runtime.find_agent_by_id(agent_id)
		if node != null:
			AgentBrain.registry.apply_record_to_node(node, true)

	# Consume snapshot once applied (explicit action semantics).
	_cutscene_agent_snapshots.erase(effective_id)

	await get_tree().process_frame

func _find_player_agent_id() -> StringName:
	# Prefer stable id.
	if AgentBrain == null or AgentBrain.registry == null:
		return &""
	var direct = AgentBrain.registry.get_record(&"player")
	if direct is AgentRecord:
		return &"player"
	# Fallback: first record tagged PLAYER.
	for r in AgentBrain.registry.list_records():
		if r != null and r.kind == Enums.AgentKind.PLAYER:
			return r.agent_id
	return &""

#endregion
