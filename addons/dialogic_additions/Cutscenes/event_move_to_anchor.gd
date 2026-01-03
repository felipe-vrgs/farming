@tool
class_name DialogicCutsceneMoveToAnchorEvent
extends DialogicEvent

## Move an actor (by id) to a named CutsceneAnchors marker.

var actor_id: StringName = &"player"
var anchor_name: StringName = &""
var speed: float = 60.0

var _tween: Tween = null

func _execute() -> void:
	if Runtime == null:
		push_warning("Cutscene.MoveToAnchor: Runtime not available.")
		finish()
		return
	if not Runtime.has_method("find_actor_by_id") or not Runtime.has_method("find_cutscene_anchor"):
		push_warning("Cutscene.MoveToAnchor: Runtime missing helper methods.")
		finish()
		return

	var actor: Node2D = Runtime.find_actor_by_id(actor_id)
	var anchor: Node2D = Runtime.find_cutscene_anchor(anchor_name)
	if actor == null:
		push_warning("Cutscene.MoveToAnchor: Actor not found: %s" % String(actor_id))
		finish()
		return
	if anchor == null:
		push_warning("Cutscene.MoveToAnchor: Anchor not found: %s" % String(anchor_name))
		finish()
		return

	var dist := actor.global_position.distance_to(anchor.global_position)
	if dist < 0.5:
		finish()
		return

	var final_speed: float = maxf(1.0, float(speed))
	var duration: float = dist / final_speed

	dialogic.current_state = dialogic.States.WAITING
	_tween = dialogic.get_tree().create_tween()
	_tween.tween_property(
		actor,
		"global_position",
		anchor.global_position,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_finish)

func _on_finish() -> void:
	if dialogic != null:
		dialogic.current_state = dialogic.States.IDLE
	finish()

func _init() -> void:
	event_name = "Cutscene: Move To Anchor"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 1

func get_shortcode() -> String:
	return "cutscene_move_to_anchor"

func get_shortcode_parameters() -> Dictionary:
	return {
		"actor_id": {"property": "actor_id", "default": &"player"},
		"anchor": {"property": "anchor_name", "default": &""},
		"speed": {"property": "speed", "default": 60.0},
	}

func build_event_editor() -> void:
	add_header_edit("actor_id", ValueType.SINGLELINE_TEXT, {"left_text":"Move", "autofocus":true})
	add_header_label("to")
	add_header_edit(
		"anchor_name", ValueType.SINGLELINE_TEXT, {
			"placeholder":"Anchor name (Marker2D under CutsceneAnchors)",
		}
	)
	add_body_edit("speed", ValueType.NUMBER, {"left_text":"Speed (px/s):", "min":1})

