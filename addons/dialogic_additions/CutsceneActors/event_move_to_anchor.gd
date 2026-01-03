@tool
extends DialogicEvent

## Move an actor (by id) to a named CutsceneAnchors marker.

const _MOVE_TWEEN_META_KEY := &"dialogic_additions_cutscene_move_tweens"

var actor_id: String = "player"
var anchor_name: String = ""
var speed: float = 60.0
var wait: bool = true
## Optional final facing direction after arriving.
## Supported values: "left", "right", "front", "back". Empty = keep natural facing.
var facing_dir: String = ""

var _tween: Tween = null
var _actor: Node2D = null
var _move_dir: Vector2 = Vector2.ZERO

func _get_move_tween_map() -> Dictionary:
	var loop := Engine.get_main_loop()
	if loop == null:
		return {}
	if not loop.has_meta(_MOVE_TWEEN_META_KEY):
		loop.set_meta(_MOVE_TWEEN_META_KEY, {})
	var d := loop.get_meta(_MOVE_TWEEN_META_KEY)
	return d if d is Dictionary else {}

func _set_move_tween_map(d: Dictionary) -> void:
	var loop := Engine.get_main_loop()
	if loop == null:
		return
	loop.set_meta(_MOVE_TWEEN_META_KEY, d)

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

	_apply_walk_visuals(true)
	_tween = dialogic.get_tree().create_tween()
	# Replace any previous move tween for this actor_id.
	var m := _get_move_tween_map()
	var prev := m.get(actor_id)
	if prev is Tween and is_instance_valid(prev):
		(prev as Tween).kill()
	m[actor_id] = _tween
	_set_move_tween_map(m)

	_tween.tween_property(
		actor,
		"global_position",
		anchor.global_position,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_tween_finished)

	if wait:
		dialogic.current_state = dialogic.States.WAITING
		return
	# Fire-and-forget: allow timeline to continue immediately.
	finish()

func _on_tween_finished() -> void:
	# Clean registry
	var m := _get_move_tween_map()
	if m.get(actor_id) == _tween:
		m.erase(actor_id)
		_set_move_tween_map(m)

	_apply_walk_visuals(false, _resolve_facing_override())
	if wait and dialogic != null:
		dialogic.current_state = dialogic.States.IDLE
		finish()

func _apply_walk_visuals(is_moving: bool, dir_override: Vector2 = Vector2.ZERO) -> void:
	# During CUTSCENE mode controllers/state machines are disabled, so we manually
	# trigger simple move/idle animations to match walking tweens.
	if _actor == null or not is_instance_valid(_actor):
		return

	var dir := dir_override
	if dir == Vector2.ZERO:
		dir = _move_dir
	if dir.length() < 0.001:
		dir = Vector2.DOWN

	# Player: prefers "move_<dir>" animations (same suffix convention as Player.gd).
	if _actor is Player:
		var p := _actor as Player
		if not p.is_inside_tree() or p.animated_sprite == null or p.animated_sprite.sprite_frames == null:
			return
		# Keep the player's facing state consistent with visuals.
		if "raycell_component" in p and p.raycell_component != null:
			p.raycell_component.facing_dir = dir
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
	event_category = "Cutscene"
	event_sorting_index = 1

func get_shortcode() -> String:
	return "cutscene_move_to_anchor"

func get_shortcode_parameters() -> Dictionary:
	return {
		"actor_id": {"property": "actor_id", "default": "player"},
		"anchor": {"property": "anchor_name", "default": ""},
		"speed": {"property": "speed", "default": 60.0},
		"wait": {"property": "wait", "default": true},
		"facing": {"property": "facing_dir", "default": ""},
	}

func build_event_editor() -> void:
	add_header_edit("actor_id", ValueType.DYNAMIC_OPTIONS, {
		"left_text":"Move",
		"autofocus":true,
		"placeholder":"Actor id",
		"mode": 0, # PURE_STRING
		"suggestions_func": CutsceneOptions.get_actor_id_suggestions,
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

