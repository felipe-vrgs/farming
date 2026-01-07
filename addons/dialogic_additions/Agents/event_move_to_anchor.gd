@tool
extends DialogicEvent

## Move an agent (by id) to a named CutsceneAnchors marker.

var agent_id: String = "player"
var anchor_name: String = ""
var speed: float = 60.0
var wait: bool = true
## Optional final facing direction after arriving.
## Supported values: "left", "right", "front", "back". Empty = keep natural facing.
var facing_dir: String = ""

var _tween: Tween = null
var _move_dir: Vector2 = Vector2.ZERO

func _execute() -> void:
	if Runtime == null:
		push_warning("MoveToAnchor: Runtime not available.")
		finish()
		return

	var agent: Node2D = Runtime.find_agent_by_id(agent_id)
	var anchor: Node2D = Runtime.find_cutscene_anchor(anchor_name)
	if agent == null or anchor == null:
		push_warning("MoveToAnchor: Agent or anchor not found: %s" % String(agent_id))
		finish()
		return

	var comp_any := ComponentFinder.find_component_in_group(agent, Groups.CUTSCENE_ACTOR_COMPONENTS)
	var comp := comp_any as CutsceneActorComponent
	if comp == null:
		push_warning("MoveToAnchor: Missing CutsceneActorComponent on agent: %s" % agent_id)
		finish()
		return

	_move_dir = (anchor.global_position - agent.global_position).normalized()

	var dist := agent.global_position.distance_to(anchor.global_position)
	if dist < 0.5:
		finish()
		return

	comp.play_cutscene_visual(true, _move_dir)

	var facing_override := _resolve_facing_override()
	_tween = comp.move_to(anchor.global_position, speed, StringName(agent_id), facing_override)
	if _tween == null or not is_instance_valid(_tween):
		if facing_override == Vector2.ZERO:
			facing_override = _move_dir
		# If we couldn't tween (already at target, missing tree, etc), don't block the timeline.
		comp.play_cutscene_visual(false, facing_override)
		finish()
		return

	if wait:
		dialogic.current_state = dialogic.States.WAITING
		_tween.finished.connect(_on_tween_finished)
		return
	# Fire-and-forget: allow timeline to continue immediately.
	finish()

func _on_tween_finished() -> void:
	if wait and dialogic != null:
		dialogic.current_state = dialogic.States.IDLE
		finish()

func _resolve_facing_override() -> Vector2:
	var s := facing_dir.strip_edges().to_lower()
	match s:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"front", "down":
			return Vector2.DOWN
		"back", "up":
			return Vector2.UP
		"", "none", "keep":
			return Vector2.ZERO
		_:
			return Vector2.ZERO

func _init() -> void:
	event_name = "Move To Anchor"
	set_default_color("Color7")
	event_category = "Agent"
	event_sorting_index = 1

func get_shortcode() -> String:
	return "cutscene_move_to_anchor"

func get_shortcode_parameters() -> Dictionary:
	return {
		"agent_id": {"property": "agent_id", "default": "player"},
		"anchor": {"property": "anchor_name", "default": ""},
		"speed": {"property": "speed", "default": 60.0},
		"wait": {"property": "wait", "default": true},
		"facing": {"property": "facing_dir", "default": ""},
	}

func build_event_editor() -> void:
	add_header_edit("agent_id", ValueType.DYNAMIC_OPTIONS, {
		"left_text":"Move agent",
		"autofocus":true,
		"placeholder":"Agent id",
		"mode": 0, # PURE_STRING
		"suggestions_func": CutsceneOptions.get_agent_id_suggestions,
	})
	add_header_label("to")
	add_header_edit(
		"anchor_name", ValueType.SINGLELINE_TEXT, {
			"placeholder":"Anchor name (Marker2D under CutsceneAnchors)",
		}
	)
	add_body_edit("speed", ValueType.NUMBER, {"left_text":"Speed (px/s):", "min":1})
	add_body_edit("wait", ValueType.BOOL, {"left_text":"Wait for arrival:"})

	add_body_edit("facing_dir", ValueType.FIXED_OPTIONS, {
		"left_text":"End facing:",
		"options": CutsceneOptions.facing_fixed_options(),
	})
