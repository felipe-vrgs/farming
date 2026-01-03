@tool
extends DialogicEvent

## Move an actor (by id) to a named CutsceneAnchors marker.

var actor_id: String = "player"
var anchor_name: String = ""
var speed: float = 60.0

var _tween: Tween = null
var _actor: Node2D = null
var _move_dir: Vector2 = Vector2.ZERO

func _execute() -> void:
	if Runtime == null:
		push_warning("MoveToAnchor: Runtime not available.")
		finish()
		return
	if not Runtime.has_method("find_actor_by_id") or not Runtime.has_method("find_cutscene_anchor"):
		push_warning("MoveToAnchor: Runtime missing helper methods.")
		finish()
		return

	var actor: Node2D = Runtime.find_actor_by_id(actor_id)
	var anchor: Node2D = Runtime.find_cutscene_anchor(anchor_name)
	if actor == null:
		push_warning("MoveToAnchor: Actor not found: %s" % String(actor_id))
		finish()
		return
	if anchor == null:
		push_warning("MoveToAnchor: Anchor not found: %s" % String(anchor_name))
		finish()
		return

	_actor = actor
	_move_dir = (anchor.global_position - actor.global_position).normalized()

	var dist := actor.global_position.distance_to(anchor.global_position)
	if dist < 0.5:
		finish()
		return

	var final_speed: float = maxf(1.0, float(speed))
	var duration: float = dist / final_speed

	dialogic.current_state = dialogic.States.WAITING
	_apply_walk_visuals(true)
	_tween = dialogic.get_tree().create_tween()
	_tween.tween_property(
		actor,
		"global_position",
		anchor.global_position,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_finish)

func _on_finish() -> void:
	_apply_walk_visuals(false)
	if dialogic != null:
		dialogic.current_state = dialogic.States.IDLE
	finish()

func _apply_walk_visuals(is_moving: bool) -> void:
	# During CUTSCENE mode controllers/state machines are disabled, so we manually
	# trigger simple move/idle animations to match walking tweens.
	if _actor == null or not is_instance_valid(_actor):
		return

	var dir := _move_dir
	if dir.length() < 0.001:
		dir = Vector2.DOWN

	# Player: prefers "move_<dir>" animations (same suffix convention as Player.gd).
	if _actor is Player:
		var p := _actor as Player
		if not p.is_inside_tree() or p.animated_sprite == null or p.animated_sprite.sprite_frames == null:
			return
		var suffix := _player_dir_suffix(dir)
		var anim := "move_%s" % suffix if is_moving else "idle_%s" % suffix
		if p.animated_sprite.sprite_frames.has_animation(anim):
			p.animated_sprite.play(anim)
		return

	# NPC: prefers "move" if present, otherwise directional "move_left/right/front/back".
	if _actor is NPC:
		var n := _actor as NPC
		if not n.is_inside_tree() or n.sprite == null or n.sprite.sprite_frames == null:
			return
		n.facing_dir = dir
		var prefix := "move" if is_moving else "idle"
		var anim_name := _npc_dir_anim_name(prefix, dir, n.sprite.sprite_frames.has_animation(prefix))
		if n.sprite.sprite_frames.has_animation(anim_name):
			n.sprite.play(anim_name)
		return

func _player_dir_suffix(dir: Vector2) -> String:
	# Copy of Player._direction_suffix (private).
	if abs(dir.x) >= abs(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "front" if dir.y > 0.0 else "back"

func _npc_dir_anim_name(prefix: String, dir: Vector2, has_undirected: bool) -> StringName:
	if has_undirected:
		return StringName(prefix)
	if abs(dir.x) > abs(dir.y):
		return StringName("%s_right" % prefix) if dir.x >= 0.0 else StringName("%s_left" % prefix)
	return StringName("%s_front" % prefix) if dir.y >= 0.0 else StringName("%s_back" % prefix)

func _init() -> void:
	event_name = "Move To Anchor"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 1

func get_shortcode() -> String:
	return "cutscene_move_to_anchor"

func get_shortcode_parameters() -> Dictionary:
	return {
		"actor_id": {"property": "actor_id", "default": "player"},
		"anchor": {"property": "anchor_name", "default": ""},
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

