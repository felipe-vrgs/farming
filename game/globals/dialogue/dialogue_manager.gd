extends Node

## Dialogue/Cutscene manager (Application facing layer).
## - Receives EventBus dialogue/cutscene start requests
## - Switches Runtime flow state (RUNNING / DIALOGUE / CUTSCENE)
## - Routes timeline requests to DialogicFacade
## - Manages agent snapshots via DialogueStateSnapshotter
## - Provides state capture/hydration for save system

signal dialogue_started(timeline_id: StringName)
signal dialogue_ended(timeline_id: StringName)

var facade: DialogicFacade = null
var snapshotter: DialogueStateSnapshotter = null

var _active: bool = false
var _current_timeline_id: StringName = &""
var _layout_node: Node = null
var _pending_hydrate: DialogueSave = null

## If a cutscene is requested while a dialogue timeline is active, we queue it and
## start it as soon as the dialogue ends.
var _queued_timeline_id: StringName = &""
var _queued_mode: Enums.FlowState = Enums.FlowState.RUNNING


func _ready() -> void:
	# Must keep running while SceneTree is paused (dialogue mode).
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Instantiate facade
	facade = DialogicFacade.new()
	add_child(facade)
	facade.timeline_ended.connect(_on_facade_timeline_ended)

	# Instantiate snapshotter
	snapshotter = DialogueStateSnapshotter.new()
	add_child(snapshotter)

	if EventBus != null:
		if (
			"dialogue_start_requested" in EventBus
			and not EventBus.dialogue_start_requested.is_connected(_on_dialogue_start_requested)
		):
			EventBus.dialogue_start_requested.connect(_on_dialogue_start_requested)

		if (
			"cutscene_start_requested" in EventBus
			and not EventBus.cutscene_start_requested.is_connected(_on_cutscene_start_requested)
		):
			EventBus.cutscene_start_requested.connect(_on_cutscene_start_requested)
		if not EventBus.day_started.is_connected(_on_day_started):
			EventBus.day_started.connect(_on_day_started)

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
	if not facade.is_dialogic_ready():
		return save

	save.dialogic_variables = facade.get_variables().duplicate(true)
	return save


func hydrate_state(save: DialogueSave) -> void:
	if save == null:
		return
	if not facade.is_dialogic_ready():
		# Dialogic not ready yet (common during boot). Defer once.
		_pending_hydrate = save
		return

	facade.set_variables(save.dialogic_variables)

	if OS.is_debug_build():
		print("DialogueManager: Hydrated state with ", save.dialogic_variables.size(), " variables")


func stop_dialogue() -> void:
	# Forcefully stop any active dialogue or cutscene and reset state.
	# Used when loading a game or quitting to menu to ensure a clean slate.
	_active = false
	_current_timeline_id = &""
	_queued_timeline_id = &""
	_queued_mode = Enums.FlowState.RUNNING
	snapshotter.clear()

	# If Dialogic fails to fully clean up the current layout (common when force-stopping
	# mid-timeline), we must free it ourselves or it can keep intercepting input.
	if (
		_layout_node != null
		and is_instance_valid(_layout_node)
		and not _layout_node.is_queued_for_deletion()
	):
		_layout_node.queue_free()
	_layout_node = null

	facade.end_fast_end()  # Reset suppression depth if any
	facade.end_timeline()
	facade.clear()

	if Runtime != null and Runtime.flow_manager != null:
		Runtime.flow_manager.request_flow_state(Enums.FlowState.RUNNING)


func restore_cutscene_agent_snapshot(agent_id: StringName) -> void:
	# Explicit restoration hook for cutscene timelines (called by Dialogic events).
	# Proxies to the snapshotter.
	await snapshotter.restore_cutscene_agent_snapshot(agent_id)


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
			(
				"DialogueManager: Cannot start dialogue, dialogue_id is empty for npc '%s'."
				% String(npc_id)
			)
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
				(
					"Queued cutscene '%s' while '%s' is active"
					% [String(_queued_timeline_id), String(_current_timeline_id)]
				)
			)
			facade.begin_fast_end()
			# Best-effort prewarm
			facade.preload_timeline(_queued_timeline_id)
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

	_active = true
	_current_timeline_id = timeline_id
	_dbg_flow("Start timeline '%s' mode=%s" % [String(timeline_id), str(int(mode))])

	# Capture pre-cutscene positions/levels for cutscene agents so we can restore
	# them after the cutscene ends (best-effort).
	if mode == Enums.FlowState.CUTSCENE:
		snapshotter.capture_cutscene_agent_snapshots()

	# Switch world-mode state first so the UI starts in the correct mode.
	if Runtime != null and Runtime.flow_manager != null:
		Runtime.flow_manager.request_flow_state(mode)

	# Suppress Dialogic's internal ending timeline/animations to ensure a fast transition
	# back to gameplay when the timeline finishes.
	facade.begin_fast_end()

	_layout_node = facade.start_timeline(timeline_id)
	if _layout_node != null:
		dialogue_started.emit(timeline_id)
		return

	push_warning("DialogueManager: Failed to start timeline via facade.")
	snapshotter.clear()
	var finished_id := _clear_active_timeline()
	# Return to RUNNING on failure.
	if Runtime != null and Runtime.flow_manager != null:
		Runtime.flow_manager.request_flow_state(Enums.FlowState.RUNNING)
	dialogue_ended.emit(finished_id)


func _clear_active_timeline() -> StringName:
	var finished_id := _current_timeline_id
	_current_timeline_id = &""
	_active = false
	# Best-effort: ensure any Dialogic layout is removed.
	if (
		_layout_node != null
		and is_instance_valid(_layout_node)
		and not _layout_node.is_queued_for_deletion()
	):
		_layout_node.queue_free()
	_layout_node = null
	return finished_id


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


func _on_facade_timeline_ended(_unused_id: StringName) -> void:
	if not _active:
		return

	var finished_id := _clear_active_timeline()
	_dbg_flow("Timeline finished '%s'" % String(finished_id))

	# Track completion for branching/persistence via Dialogic variables.
	if not String(finished_id).is_empty():
		facade.set_completed_timeline(finished_id)

	# Cutscene agent restores are explicit (performed by a Dialogic event in the timeline).
	# Clear any remaining snapshots when the cutscene ends.
	if String(finished_id).begins_with("cutscenes/"):
		snapshotter.clear()

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

	# Return to RUNNING as soon as we know we're not chaining another timeline.
	# This unpauses the game tree so the transition back to gameplay is not
	# delayed by the subsequent cleanup and state tracking logic.
	if Runtime != null and Runtime.flow_manager != null:
		Runtime.flow_manager.request_flow_state(Enums.FlowState.RUNNING)

	facade.end_fast_end()

	dialogue_ended.emit(finished_id)

	# Keep the "no-save window" minimal: autosave immediately after the timeline ends.
	# We yield a frame to let the UI update and input process so the "hitch" isn't felt
	# during the transition back to gameplay.
	if Runtime != null:
		await get_tree().process_frame
		Runtime.autosave_session()


func _dbg_flow(msg: String) -> void:
	if not OS.is_debug_build():
		return
	print("DialogueManager[%d]: %s" % [Time.get_ticks_msec(), msg])


func _on_day_started(_day_index: int) -> void:
	reset_daily_flags()


func reset_daily_flags() -> void:
	var vars = facade.get_variables()
	if vars.is_empty():
		return
	_reset_daily_flags_in_dict(vars)


func _reset_daily_flags_in_dict(d: Dictionary) -> void:
	for k in d.keys():
		var v = d[k]
		if v is Dictionary:
			_reset_daily_flags_in_dict(v)
			continue
		# Convention: any variable key ending in "_today" resets to false.
		if String(k).ends_with("_today"):
			d[k] = false

#endregion
