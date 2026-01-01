extends Node

## V1 dialogue integration layer.
## - Listens to EventBus.talk_requested (from TalkOnInteract)
## - Starts Dialogic (if installed)
## - Pauses TimeManager and locks player input while dialogue is active
##
## This file intentionally does not hard-depend on Dialogic types.

const PAUSE_REASON := &"dialogue"

var _active: bool = false
var _locked_player: Node = null
var _dialogic: Node = null

func _ready() -> void:
	if EventBus != null and not EventBus.talk_requested.is_connected(_on_talk_requested):
		EventBus.talk_requested.connect(_on_talk_requested)

	_dialogic = get_node_or_null(NodePath("/root/Dialogic"))
	if _dialogic != null:
		_connect_dialogic_signals(_dialogic)

func _on_talk_requested(actor: Node, npc: Node, dialogue_id: StringName) -> void:
	if _active:
		return

	_active = true
	_lock_world(actor)

	# Prefer explicit timeline id; fall back to npc name.
	var timeline := String(dialogue_id)
	if timeline.is_empty() and npc != null:
		timeline = String(npc.name)

	if _dialogic == null:
		push_warning("DialogicIntegrator: Dialogic not found at /root/Dialogic (install Dialogic 2).")
		_unlock_world()
		return

	# Dialogic 2 API is intentionally invoked via has_method to avoid hard deps.
	if _dialogic.has_method("start_timeline"):
		_dialogic.call("start_timeline", timeline)
		return
	if _dialogic.has_method("start"):
		_dialogic.call("start", timeline)
		return

	push_warning("DialogicIntegrator: Dialogic node found, but no start method detected.")
	_unlock_world()

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

	_active = false

func _connect_dialogic_signals(d: Node) -> void:
	# Best-effort: connect to "end of dialogue" notifications if available.
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

