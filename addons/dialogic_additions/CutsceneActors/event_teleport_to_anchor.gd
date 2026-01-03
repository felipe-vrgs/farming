@tool
extends DialogicEvent

## Teleport an actor (by id) to a named CutsceneAnchors marker.

var actor_id: String = "player"
var anchor_name: String = ""

func _execute() -> void:
	if Runtime == null:
		push_warning("TeleportToAnchor: Runtime not available.")
		finish()
		return
	if not Runtime.has_method("find_actor_by_id") or not Runtime.has_method("find_cutscene_anchor"):
		push_warning("TeleportToAnchor: Runtime missing helper methods.")
		finish()
		return

	var actor: Node2D = Runtime.find_actor_by_id(actor_id)
	var anchor: Node2D = Runtime.find_cutscene_anchor(anchor_name)
	if actor == null:
		push_warning("TeleportToAnchor: Actor not found: %s" % String(actor_id))
		finish()
		return
	if anchor == null:
		push_warning("TeleportToAnchor: Anchor not found: %s" % String(anchor_name))
		finish()
		return

	actor.global_position = anchor.global_position
	finish()

func _init() -> void:
	event_name = "Teleport To Anchor"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 2

func get_shortcode() -> String:
	return "cutscene_teleport_to_anchor"

func get_shortcode_parameters() -> Dictionary:
	return {
		"actor_id": {"property": "actor_id", "default": "player"},
		"anchor": {"property": "anchor_name", "default": ""},
	}

func build_event_editor() -> void:
	add_header_edit("actor_id", ValueType.SINGLELINE_TEXT, {"left_text":"Teleport", "autofocus":true})
	add_header_label("to")
	add_header_edit("anchor_name", ValueType.SINGLELINE_TEXT, {
		"placeholder":"Anchor name (Marker2D under CutsceneAnchors)"
	})

