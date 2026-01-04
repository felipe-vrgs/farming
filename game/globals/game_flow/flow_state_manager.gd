extends Node

## FlowStateManager - manages high-level game flow states (RUNNING, DIALOGUE, CUTSCENE).
## Handles input locking, UI toggles, and coordination with TimeManager and UIManager.

const _PAUSE_REASON_DIALOGUE := &"dialogue"
const _PAUSE_REASON_CUTSCENE := &"cutscene"

## World-mode flow state (orthogonal to GameFlow menu/pause).
var flow_state: Enums.FlowState = Enums.FlowState.RUNNING

## Cache of whether SceneTree was paused before entering dialogue mode.
var _tree_paused_before_dialogue: bool = false

# Reference to GameRuntime for accessing shared dependencies.
var _runtime: Node = null


func setup(runtime: Node) -> void:
	_runtime = runtime


func request_flow_state(next: Enums.FlowState) -> void:
	if flow_state == next:
		return

	# Guarantee a save before entering a state that disables autosaving (cutscene/dialogue).
	if flow_state == Enums.FlowState.RUNNING and next != Enums.FlowState.RUNNING:
		if _runtime.has_method("autosave_session"):
			_runtime.autosave_session()

	flow_state = next
	apply_flow_state()


func apply_flow_state() -> void:
	# Cooperate with GameFlow pause menu: never force-unpause if user is in PAUSED.
	var is_pause_menu_active := false
	if _runtime != null and _runtime.game_flow != null and "state" in _runtime.game_flow:
		is_pause_menu_active = int(_runtime.game_flow.get("state")) == 4

	match flow_state:
		Enums.FlowState.RUNNING:
			# Resume controller input/simulation.
			_set_player_input_enabled(true)
			_set_npc_controllers_enabled(true)
			# Cutscene vignette off.
			if UIManager != null and UIManager.has_method("get_screen_node"):
				var v := UIManager.get_screen_node(UIManager.ScreenName.VIGNETTE)
				if v != null and is_instance_valid(v) and v.has_method("fade_out"):
					v.call("fade_out", 0.15)
			# HUD/hotbar on.
			_set_hotbar_visible(true)
			if TimeManager != null:
				TimeManager.resume(_PAUSE_REASON_DIALOGUE)
				TimeManager.resume(_PAUSE_REASON_CUTSCENE)
			# Only unpause the tree if it wasn't paused by something else (pause menu).
			if not is_pause_menu_active and get_tree().paused and not _tree_paused_before_dialogue:
				get_tree().paused = false
			_tree_paused_before_dialogue = false

		Enums.FlowState.DIALOGUE:
			# Full pause. UI/dialogue nodes should opt into PROCESS_MODE_ALWAYS.
			_tree_paused_before_dialogue = get_tree().paused
			_set_player_input_enabled(false)
			_set_npc_controllers_enabled(false)
			if TimeManager != null:
				TimeManager.pause(_PAUSE_REASON_DIALOGUE)
			if not is_pause_menu_active:
				get_tree().paused = true
			# HUD/hotbar off during dialogue.
			_set_hotbar_visible(false)

		Enums.FlowState.CUTSCENE:
			# Keep the SceneTree running but disable controllers so cutscene scripts
			# can move actors without AI/waypoints fighting them.
			_set_player_input_enabled(false)
			_set_npc_controllers_enabled(false)
			# Cutscene vignette on (subtle).
			if UIManager != null and UIManager.has_method("show"):
				var v := UIManager.show(UIManager.ScreenName.VIGNETTE)
				if v != null and v.has_method("fade_in"):
					v.call("fade_in", 0.15)
			# HUD/hotbar off during cutscene.
			_set_hotbar_visible(false)
			if TimeManager != null:
				TimeManager.pause(_PAUSE_REASON_CUTSCENE)
			# Ensure we are not tree-paused unless the pause menu is active.
			if not is_pause_menu_active and get_tree().paused and not _tree_paused_before_dialogue:
				get_tree().paused = false


func _on_loading_started() -> void:
	_set_player_input_enabled(false)
	_set_npc_controllers_enabled(false)


func _on_loading_finished() -> void:
	apply_flow_state()


func _set_hotbar_visible(visible: bool) -> void:
	if UIManager == null or not UIManager.has_method("get_screen_node"):
		return
	var hud := UIManager.get_screen_node(UIManager.ScreenName.HUD)
	if hud != null and is_instance_valid(hud) and hud.has_method("set_hotbar_visible"):
		hud.call("set_hotbar_visible", visible)


func _set_player_input_enabled(enabled: bool) -> void:
	if AgentBrain != null:
		var p := AgentBrain.get_agent_node(&"player")
		if p != null and p.has_method("set_input_enabled"):
			p.call("set_input_enabled", enabled)


func _set_npc_controllers_enabled(enabled: bool) -> void:
	# Keep this best-effort: only NPCs that implement the method are affected.
	var npcs := get_tree().get_nodes_in_group(Groups.NPC_GROUP)
	for n in npcs:
		if n != null and n.has_method("set_controller_enabled"):
			n.call("set_controller_enabled", enabled)
