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


class DeferredRestoreRequest:
	var agent_ids: PackedStringArray = PackedStringArray()
	var auto_blackout: bool = false
	var blackout_time: float = 0.25


## If a cutscene is requested while a dialogue timeline is active, we queue it and
## start it as soon as the dialogue ends.
var _queued_timeline_id: StringName = &""
var _queued_mode: Enums.FlowState = Enums.FlowState.RUNNING

## Post-timeline (cutscene) restore queue.
## Used by Dialogic events to schedule blackout+restore AFTER the timeline ends.
var _deferred_restores: Array[DeferredRestoreRequest] = []


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


func stop_dialogue(preserve_variables: bool = false) -> void:
	# Forcefully stop any active dialogue or cutscene and reset state.
	# - preserve_variables=true is used for scene/level transitions inside the same session,
	#   where Dialogic variable state should remain intact.
	# - preserve_variables=false is used for boot/new-game/load/quit flows where we want a clean slate.
	_active = false
	_current_timeline_id = &""
	_queued_timeline_id = &""
	_queued_mode = Enums.FlowState.RUNNING
	_deferred_restores.clear()
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
	if not preserve_variables:
		facade.clear()

	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.request_flow_state(Enums.FlowState.RUNNING)


func restore_cutscene_agent_snapshot(agent_id: StringName) -> void:
	# Explicit restoration hook for cutscene timelines (called by Dialogic events).
	# Proxies to the snapshotter.
	await snapshotter.restore_cutscene_agent_snapshot(agent_id)


## Queue a restore request to be executed AFTER the current timeline ends.
func queue_cutscene_restore_after_timeline(
	agent_ids: PackedStringArray, auto_blackout: bool = true, blackout_time: float = 0.25
) -> void:
	if agent_ids.is_empty():
		return
	var req := DeferredRestoreRequest.new()
	req.agent_ids = agent_ids
	req.auto_blackout = auto_blackout
	req.blackout_time = blackout_time
	_deferred_restores.append(req)


## Cutscene helper: temporarily hide/show the active Dialogic layout node (textbox, etc).
## Used by blackout events to prevent the dialogue UI from flashing during fade transitions.
func set_layout_visible(visible: bool) -> void:
	if _layout_node == null or not is_instance_valid(_layout_node):
		return
	# Most Dialogic layouts are Controls (CanvasItem). Handle best-effort.
	if _layout_node is CanvasItem:
		(_layout_node as CanvasItem).visible = visible
		return
	if "visible" in _layout_node:
		_layout_node.visible = visible


#endregion


func _blackout_begin(time: float) -> void:
	if UIManager == null or not UIManager.has_method("blackout_begin"):
		return
	set_layout_visible(false)
	await UIManager.blackout_begin(maxf(0.0, time))


func _blackout_end(time: float) -> void:
	if UIManager == null or not UIManager.has_method("blackout_end"):
		return
	# Keep Dialogic layout hidden during fade-in.
	set_layout_visible(false)
	await UIManager.blackout_end(maxf(0.0, time))
	# Defer re-show by 1 frame to avoid flashes if layout is freed on timeline end.
	await get_tree().process_frame
	set_layout_visible(true)


func _run_deferred_cutscene_restores() -> void:
	if _deferred_restores.is_empty():
		return
	# Consume queue so it can't run twice.
	var q: Array[DeferredRestoreRequest] = []
	for req: DeferredRestoreRequest in _deferred_restores:
		q.append(req)
	_deferred_restores.clear()

	for req: DeferredRestoreRequest in q:
		if req == null or req.agent_ids.is_empty():
			continue
		if req.auto_blackout:
			await _blackout_begin(req.blackout_time)
		for id in req.agent_ids:
			if String(id).is_empty():
				continue
			await restore_cutscene_agent_snapshot(id)
		if req.auto_blackout:
			await _blackout_end(req.blackout_time)


#endregion

#region EventBus receivers


func _on_dialogue_start_requested(_agent: Node, npc: Node, dialogue_id: StringName) -> void:
	if _active:
		return

	_turn_npc_toward_player(npc)
	_turn_player_toward_npc(npc)

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


func _turn_npc_toward_player(npc: Node) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	if not (npc is Node2D):
		return

	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node2D
	if player == null or not is_instance_valid(player):
		return

	var comp_any := ComponentFinder.find_component_in_group(npc, Groups.CUTSCENE_ACTOR_COMPONENTS)
	var comp := comp_any as CutsceneActorComponent
	if comp == null:
		push_warning(
			"DialogueManager: Missing CutsceneActorComponent on npc: %s" % String(npc.name)
		)
		return

	comp.face_toward(player.global_position, true)


func _turn_player_toward_npc(npc: Node) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	if not (npc is Node2D):
		return

	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node2D
	if player == null or not is_instance_valid(player):
		return

	var comp_any := ComponentFinder.find_component_in_group(
		player, Groups.CUTSCENE_ACTOR_COMPONENTS
	)
	var comp := comp_any as CutsceneActorComponent
	if comp == null:
		push_warning("DialogueManager: Missing CutsceneActorComponent on player")
		return

	comp.face_toward((npc as Node2D).global_position, true)


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
	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.request_flow_state(mode)

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
	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.request_flow_state(Enums.FlowState.RUNNING)
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
	# Belt-and-suspenders teardown: ensure Dialogic itself is no longer holding on to any
	# layout/textbox after a timeline ends. This is intentionally idempotent.
	facade.end_timeline()
	_dbg_flow("Timeline finished '%s'" % String(finished_id))

	# Track completion for branching/persistence via Dialogic variables.
	if not String(finished_id).is_empty():
		facade.set_completed_timeline(finished_id)

	var finished_is_cutscene := String(finished_id).begins_with("cutscenes/")
	if finished_is_cutscene:
		# Run any deferred restore requests now (AFTER timeline end, BEFORE returning to RUNNING).
		# This avoids UI flicker from in-timeline blackout events.
		await _run_deferred_cutscene_restores()
		# Clear snapshots after restores are done.
		snapshotter.clear()

	# If a cutscene was queued during dialogue, start it now (do not return to RUNNING in-between).
	var next_timeline_id := _queued_timeline_id
	var next_mode := _queued_mode
	_queued_timeline_id = &""
	_queued_mode = Enums.FlowState.RUNNING

	if not String(next_timeline_id).is_empty():
		_dbg_flow("Chaining to '%s' mode=%s" % [String(next_timeline_id), str(int(next_mode))])
		dialogue_ended.emit(finished_id)
		# IMPORTANT: queueing a cutscene during dialogue already called begin_fast_end()
		# to fast-end the current dialogue timeline. Starting the next timeline will
		# call begin_fast_end() again. Without balancing here, the suppression depth
		# leaks and the Dialogic textbox can remain stuck across timelines.
		facade.end_fast_end()
		_start_timeline(next_timeline_id, next_mode)
		return

	# Return to RUNNING as soon as we know we're not chaining another timeline.
	# This unpauses the game tree so the transition back to gameplay is not
	# delayed by the subsequent cleanup and state tracking logic.
	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.request_flow_state(Enums.FlowState.RUNNING)

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
