class_name GameplayUtils
extends Object

## Centralized helpers for gameplay state manipulation.


static func set_player_input_enabled(scene_tree: SceneTree, enabled: bool) -> void:
	# Prefer AgentBrain lookup (works even before Player is fully grouped).
	if is_instance_valid(AgentBrain) and AgentBrain.has_method("get_agent_node"):
		var p = AgentBrain.get_agent_node(&"player")
		if p != null and p.has_method("set_input_enabled"):
			p.call("set_input_enabled", enabled)
			return

	# Fallback: group-based.
	var nodes := scene_tree.get_nodes_in_group(&"player")
	if not nodes.is_empty():
		var p = nodes[0]
		if p.has_method("set_input_enabled"):
			p.call("set_input_enabled", enabled)


static func set_player_action_input_enabled(scene_tree: SceneTree, enabled: bool) -> void:
	# Action input: tool use / interactions / hotbar selection.
	if is_instance_valid(AgentBrain) and AgentBrain.has_method("get_agent_node"):
		var p = AgentBrain.get_agent_node(&"player")
		if p != null and p.has_method("set_action_input_enabled"):
			p.call("set_action_input_enabled", enabled)
			return

	var nodes := scene_tree.get_nodes_in_group(&"player")
	if not nodes.is_empty():
		var p = nodes[0]
		if p.has_method("set_action_input_enabled"):
			p.call("set_action_input_enabled", enabled)


static func set_npc_controllers_enabled(scene_tree: SceneTree, enabled: bool) -> void:
	# Best-effort: only NPCs that implement the method are affected.
	# NOTE: canonical group is `Groups.NPC_GROUP` ("npc"). Keep a fallback for older scenes.
	var npcs := scene_tree.get_nodes_in_group(Groups.NPC_GROUP)
	if npcs.is_empty():
		npcs = scene_tree.get_nodes_in_group(&"npcs")
	for n in npcs:
		if n != null and n.has_method("set_controller_enabled"):
			n.call("set_controller_enabled", enabled)


static func set_hotbar_visible(enabled: bool) -> void:
	if is_instance_valid(UIManager) and UIManager.has_method("get_screen_node"):
		var hud = UIManager.get_screen_node(UIManager.ScreenName.HUD)
		if hud != null and is_instance_valid(hud) and hud.has_method("set_hotbar_visible"):
			hud.call("set_hotbar_visible", enabled)


static func fade_vignette_in(duration: float = 0.15) -> void:
	if is_instance_valid(UIManager) and UIManager.has_method("show"):
		var v = UIManager.show(UIManager.ScreenName.VIGNETTE)
		if v != null and v.has_method("fade_in"):
			v.call("fade_in", maxf(0.0, duration))


static func fade_vignette_out(duration: float = 0.15) -> void:
	if is_instance_valid(UIManager) and UIManager.has_method("get_screen_node"):
		var v = UIManager.get_screen_node(UIManager.ScreenName.VIGNETTE)
		if v != null and is_instance_valid(v) and v.has_method("fade_out"):
			v.call("fade_out", maxf(0.0, duration))
