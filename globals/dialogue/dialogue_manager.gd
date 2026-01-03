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

func start_cutscene(cutscene_id: StringName, actor: Node = null) -> void:
	_on_cutscene_start_requested(cutscene_id, actor)

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

func _on_dialogue_start_requested(_actor: Node, npc: Node, dialogue_id: StringName) -> void:
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

func _on_cutscene_start_requested(cutscene_id: StringName, _actor: Node) -> void:
	if _active:
		push_warning("DialogueManager: Cannot start cutscene, dialogue already active.")
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

	# Switch world-mode state first so the UI starts in the correct mode.
	if Runtime != null and Runtime.has_method("request_flow_state"):
		Runtime.request_flow_state(mode)

	# Ensure Dialogic keeps running when SceneTree is paused (dialogue mode).
	_dialogic.process_mode = Node.PROCESS_MODE_ALWAYS

	dialogue_started.emit(timeline_id)

	# Prefer Dialogic.start(path) which ensures a layout scene is present.
	if _dialogic.has_method("start"):
		_layout_node = _dialogic.call("start", timeline_path)
		_apply_dialogic_layout_overrides(_layout_node)
		return

	push_warning("DialogueManager: Dialogic node found, but no start() method detected.")
	_end_timeline_internal()

func _end_timeline_internal() -> void:
	var finished_id := _current_timeline_id
	_current_timeline_id = &""
	_active = false

	# Return to RUNNING when timeline ends.
	if Runtime != null and Runtime.has_method("request_flow_state"):
		Runtime.request_flow_state(Enums.FlowState.RUNNING)

	dialogue_ended.emit(finished_id)

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
	_end_timeline_internal()

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

#endregion

