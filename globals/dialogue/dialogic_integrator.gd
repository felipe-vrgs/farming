extends Node

## Dialogue integration layer (v2).
## - Listens to EventBus.talk_requested (from TalkOnInteract)
## - Starts Dialogic timelines
## - Pauses TimeManager and locks player input while dialogue is active
## - Provides state capture/hydration for save system
##
## This file intentionally does not hard-depend on Dialogic types.

signal dialogue_started(timeline_id: StringName)
signal dialogue_ended(timeline_id: StringName)

const PAUSE_REASON := &"dialogue"
const TIMELINES_ROOT := "res://globals/dialogue/timelines/"

var _active: bool = false
var _locked_player: Node = null
var _dialogic: Node = null
var _current_timeline_id: StringName = &""

func _ready() -> void:
	if EventBus != null and not EventBus.talk_requested.is_connected(_on_talk_requested):
		EventBus.talk_requested.connect(_on_talk_requested)
	if EventBus != null and not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)

	_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic != null:
		_connect_dialogic_signals(_dialogic)


#region Public API

## Start an NPC dialogue. Called via EventBus.talk_requested.
## timeline_id format: "npcs/frieren/greeting" (no .dtl extension)
func _on_talk_requested(actor: Node, npc: Node, dialogue_id: StringName) -> void:
	if OS.is_debug_build():
		print("DialogicIntegrator: talk_requested: ",
				actor.name if actor else "null", " ",
				npc.name if npc else "null", " ", dialogue_id)
	if _active:
		return

	var npc_id := _get_npc_id(npc)
	# Fallback: if dialogue_id is empty, try to derive from NPC config
	if String(dialogue_id).is_empty() and npc != null:
		if not String(npc_id).is_empty():
			dialogue_id = "greeting"

	var timeline_id := StringName("npcs/" + String(npc_id) + "/" + String(dialogue_id))
	_start_timeline(timeline_id, actor, npc)


## Start a cutscene timeline (non-NPC dialogue).
## cutscene_id format: "intro" -> resolves to "cutscenes/intro"
func start_cutscene(cutscene_id: StringName, actor: Node = null) -> void:
	if _active:
		push_warning("DialogicIntegrator: Cannot start cutscene, dialogue already active.")
		return
	var timeline_id := StringName("cutscenes/" + String(cutscene_id))
	_start_timeline(timeline_id, actor, null)


## Capture current Dialogic state for saving.
func capture_state() -> DialogueSave:
	var save := DialogueSave.new()
	if _dialogic == null:
		return save

	# Capture Dialogic.VAR dictionary
	if "VAR" in _dialogic:
		var var_obj = _dialogic.get("VAR")
		if var_obj != null and var_obj.has_method("get_variables"):
			save.dialogic_variables = var_obj.get_variables().duplicate(true)
		elif var_obj is Dictionary:
			save.dialogic_variables = var_obj.duplicate(true)

	return save


## Restore Dialogic state from a save.
func hydrate_state(save: DialogueSave) -> void:
	if save == null or _dialogic == null:
		return

	if "VAR" in _dialogic:
		var var_obj = _dialogic.get("VAR")
		if var_obj != null and var_obj.has_method("set_variable"):
			for key in save.dialogic_variables:
				var_obj.set_variable(key, save.dialogic_variables[key])
		elif var_obj is Dictionary:
			for key in save.dialogic_variables:
				var_obj[key] = save.dialogic_variables[key]

	if OS.is_debug_build():
		print("DialogicIntegrator: Hydrated state with ",
				save.dialogic_variables.size(), " variables")


## Check if dialogue is currently active.
func is_active() -> bool:
	return _active

#endregion

#region Internal

func _start_timeline(timeline_id: StringName, actor: Node, _npc: Node) -> void:
	if String(timeline_id).is_empty():
		push_warning("DialogicIntegrator: Empty timeline_id, cannot start dialogue.")
		return

	_active = true
	_current_timeline_id = timeline_id
	_lock_world(actor)

	var timeline_path := _resolve_timeline_path(timeline_id)

	if _dialogic == null:
		push_warning("DialogicIntegrator: Dialogic not found at /root/Dialogic.")
		_unlock_world()
		return

	if not ResourceLoader.exists(timeline_path):
		push_warning("DialogicIntegrator: Timeline not found: ", timeline_path)
		_unlock_world()
		return

	dialogue_started.emit(timeline_id)

	# Dialogic 2 API
	if _dialogic.has_method("start"):
		_dialogic.call("start", timeline_path)
		return

	push_warning("DialogicIntegrator: Dialogic node found, but no start method detected.")
	_unlock_world()


func _resolve_timeline_path(timeline_id: StringName) -> String:
	return TIMELINES_ROOT + String(timeline_id) + ".dtl"


func _get_npc_id(npc: Node) -> StringName:
	# Try to get npc_id from NPC's agent_component or npc_config
	if npc.has_method("get") and "agent_component" in npc:
		var ac = npc.get("agent_component")
		if ac != null and "agent_id" in ac:
			return ac.agent_id
	if npc.has_method("get") and "npc_config" in npc:
		var cfg = npc.get("npc_config")
		if cfg != null and "npc_id" in cfg:
			return cfg.npc_id
	return &""


func _lock_world(actor: Node) -> void:
	if TimeManager != null:
		TimeManager.pause(PAUSE_REASON)

	_locked_player = null
	if actor != null and actor.is_in_group(Groups.PLAYER):
		_locked_player = actor
	else:
		_locked_player = get_tree().get_first_node_in_group(Groups.PLAYER)

	if _locked_player != null and _locked_player.has_method("set_input_enabled"):
		_locked_player.call("set_input_enabled", false)


func _unlock_world() -> void:
	if _locked_player != null and _locked_player.has_method("set_input_enabled"):
		_locked_player.call("set_input_enabled", true)
	_locked_player = null

	if TimeManager != null:
		TimeManager.resume(PAUSE_REASON)

	var finished_id := _current_timeline_id
	_current_timeline_id = &""
	_active = false

	dialogue_ended.emit(finished_id)


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
	_unlock_world()


func _on_day_started(_day_index: int) -> void:
	# Reset daily dialogue flags (e.g., "talked_today") at the start of each day.
	reset_daily_flags()


## Reset all "*_today" or similar daily flags in Dialogic variables.
## Convention: any variable ending with "_today" gets reset to false.
func reset_daily_flags() -> void:
	if _dialogic == null:
		return

	if "VAR" not in _dialogic:
		return

	var var_obj = _dialogic.get("VAR")
	if var_obj == null:
		return

	# Get all variables and reset daily ones
	var variables: Dictionary = {}
	if var_obj.has_method("get_variables"):
		variables = var_obj.get_variables()
	elif var_obj is Dictionary:
		variables = var_obj

	for key in variables:
		if String(key).ends_with("_today") or String(key).ends_with(".talked_today"):
			if var_obj.has_method("set_variable"):
				var_obj.set_variable(key, false)
			elif var_obj is Dictionary:
				var_obj[key] = false

	if OS.is_debug_build():
		print("DialogicIntegrator: Reset daily dialogue flags")

#endregion

