@tool
extends DialogicEvent

## Teleport an agent (by id) to a named CutsceneAnchors marker.

var agent_id: String = "player"
var anchor_name: String = ""

func _execute() -> void:
	if Runtime == null:
		push_warning("TeleportToAnchor: Runtime not available.")
		finish()
		return
	if not Runtime.has_method("find_agent_by_id") or not Runtime.has_method("find_cutscene_anchor"):
		push_warning("TeleportToAnchor: Runtime missing helper methods.")
		finish()
		return

	var agent: Node2D = Runtime.find_agent_by_id(agent_id)
	var anchor: Node2D = Runtime.find_cutscene_anchor(anchor_name)
	if agent == null:
		push_warning("TeleportToAnchor: Agent not found: %s" % String(agent_id))
		finish()
		return
	if anchor == null:
		push_warning("TeleportToAnchor: Anchor not found: %s" % String(anchor_name))
		finish()
		return

	var comp_any := ComponentFinder.find_component_in_group(agent, Groups.CUTSCENE_ACTOR_COMPONENTS)
	var comp := comp_any as CutsceneActorComponent
	if comp == null:
		push_warning("TeleportToAnchor: Missing CutsceneActorComponent on agent: %s" % agent_id)
		finish()
		return

	comp.teleport_to(anchor.global_position)
	finish()

func _init() -> void:
	event_name = "Teleport To Anchor"
	set_default_color("Color7")
	event_category = "Agent"
	event_sorting_index = 2

func get_shortcode() -> String:
	return "cutscene_teleport_to_anchor"

func get_shortcode_parameters() -> Dictionary:
	return {
		"agent_id": {"property": "agent_id", "default": "player"},
		"anchor": {"property": "anchor_name", "default": ""},
	}

func build_event_editor() -> void:
	add_header_edit("agent_id", ValueType.DYNAMIC_OPTIONS, {
		"left_text":"Teleport agent",
		"autofocus":true,
		"placeholder":"Agent id",
		"mode": 0, # PURE_STRING
		"suggestions_func": CutsceneOptions.get_agent_id_suggestions,
	})
	add_header_label("to")
	add_header_edit("anchor_name", ValueType.SINGLELINE_TEXT, {
		"placeholder":"Anchor name (Marker2D under CutsceneAnchors)"
	})
