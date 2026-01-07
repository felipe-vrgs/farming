class_name CutsceneActorComponent
extends Node

## Unified "actor control" surface for cutscenes/dialogue.
## This component is REQUIRED on actors used by Dialogic cutscene events.

const _MOVE_TWEEN_META_KEY := &"dialogic_additions_cutscene_move_tweens"


func _enter_tree() -> void:
	# Use literal to avoid cross-file symbol resolution issues in tooling.
	add_to_group(Groups.CUTSCENE_ACTOR_COMPONENTS)


func get_entity() -> Node:
	# Mirror InteractableComponent.get_entity() convention so composition works
	# regardless of whether this component is placed directly under the entity
	# or under an entity's `Components/` container.
	var p := get_parent()
	if p == null:
		return null
	if StringName(p.name) == &"Components":
		return p.get_parent()
	return p


func set_controls_enabled(enabled: bool) -> void:
	var e := get_entity()
	if e == null or not is_instance_valid(e):
		return

	if e is Player:
		var p := e as Player
		if p.has_method("set_input_enabled"):
			p.set_input_enabled(enabled)
		return

	if e is NPC:
		var n := e as NPC
		if n.has_method("set_controller_enabled"):
			n.set_controller_enabled(enabled)
		return

	# Best-effort fallback for future actor types.
	if e.has_method("set_input_enabled"):
		e.call("set_input_enabled", enabled)
	elif e.has_method("set_controller_enabled"):
		e.call("set_controller_enabled", enabled)


func face_toward(target_pos: Vector2, refresh_idle: bool = true) -> void:
	var e := get_entity()
	if e == null or not is_instance_valid(e):
		return
	if not (e is Node2D):
		return

	var v := target_pos - (e as Node2D).global_position
	if v.length() < 0.001:
		return

	var dir := _quantize_to_cardinal(v)
	set_facing_dir(dir)
	if refresh_idle:
		_refresh_idle_visuals(dir)


func set_facing_dir(dir: Vector2) -> void:
	var e := get_entity()
	if e == null or not is_instance_valid(e):
		return

	var d := dir
	if d.length() < 0.001:
		d = Vector2.DOWN

	if e is Player:
		var p := e as Player
		if "raycell_component" in p and p.raycell_component != null:
			p.raycell_component.facing_dir = d
		return

	if e is NPC:
		var n := e as NPC
		n.facing_dir = d
		return

	# Best-effort fallback (matches AgentComponent.apply_record/capture_into_record convention).
	if "facing_dir" in e:
		e.facing_dir = d


func teleport_to(
	pos: Vector2, facing_override: Vector2 = Vector2.ZERO, refresh_idle: bool = true
) -> void:
	var e := get_entity()
	if e == null or not is_instance_valid(e):
		return
	if not (e is Node2D):
		return

	(e as Node2D).global_position = pos

	if facing_override != Vector2.ZERO:
		set_facing_dir(facing_override)

	if refresh_idle:
		var dir := facing_override if facing_override != Vector2.ZERO else _get_current_facing_dir()
		_refresh_idle_visuals(dir)


func play_cutscene_visual(
	is_moving: bool, dir: Vector2, prefer_undirected_npc: bool = true
) -> void:
	# During CUTSCENE mode controllers/state machines are disabled, so we manually
	# trigger simple move/idle animations to match movement tweens.
	var e := get_entity()
	if e == null or not is_instance_valid(e):
		return

	var d := dir
	if d.length() < 0.001:
		d = Vector2.DOWN

	if e is Player:
		var p := e as Player
		if (
			not p.is_inside_tree()
			or p.animated_sprite == null
			or p.animated_sprite.sprite_frames == null
		):
			return
		# Keep the player's facing state consistent with visuals.
		if "raycell_component" in p and p.raycell_component != null:
			p.raycell_component.facing_dir = d
		var suffix := _player_dir_suffix(d)
		var anim := "move_%s" % suffix if is_moving else "idle_%s" % suffix
		if p.animated_sprite.sprite_frames.has_animation(anim):
			p.animated_sprite.play(anim)
		return

	if e is NPC:
		var n := e as NPC
		if not n.is_inside_tree() or n.sprite == null or n.sprite.sprite_frames == null:
			return
		n.facing_dir = d
		var prefix := "move" if is_moving else "idle"
		var has_undirected := prefer_undirected_npc and n.sprite.sprite_frames.has_animation(prefix)
		var anim_name := _npc_dir_anim_name(prefix, d, has_undirected)
		if n.sprite.sprite_frames.has_animation(anim_name):
			n.sprite.play(anim_name)
		return


func move_to(
	target_pos: Vector2,
	speed: float,
	agent_key: StringName,
	facing_override: Vector2 = Vector2.ZERO
) -> Tween:
	var e := get_entity()
	if e == null or not is_instance_valid(e):
		return null
	if not (e is Node2D):
		return null

	var key := String(agent_key)
	if key.is_empty():
		return null

	var n2 := e as Node2D
	var dist := n2.global_position.distance_to(target_pos)
	if dist < 0.001:
		return null

	var final_speed := maxf(1.0, float(speed))
	var duration := dist / final_speed

	var tween := get_tree().create_tween()
	# Replace any previous move tween for this agent_id.
	var m := _get_move_tween_map(true)
	var prev_any: Variant = m.get(key)
	if prev_any is Tween and is_instance_valid(prev_any):
		(prev_any as Tween).kill()
	m[key] = tween
	_set_move_tween_map(m)

	(
		tween
		. tween_property(n2, "global_position", target_pos, duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	# Cleanup registry + end visuals.
	tween.finished.connect(
		func() -> void:
			var mm := _get_move_tween_map(false)
			if mm.get(key) == tween:
				mm.erase(key)
				_set_move_tween_map(mm)

			var end_dir := (
				facing_override if facing_override != Vector2.ZERO else _get_current_facing_dir()
			)
			play_cutscene_visual(false, end_dir)
	)

	return tween


func _refresh_idle_visuals(dir: Vector2) -> void:
	var e := get_entity()
	if e == null or not is_instance_valid(e):
		return

	# Prefer state machine refresh (keeps state consistent), fall back to cutscene visuals.
	if e is Player:
		var p := e as Player
		if "state_machine" in p and p.state_machine != null:
			p.state_machine.change_state(PlayerStateNames.IDLE)
			return
		play_cutscene_visual(false, dir)
		return

	if e is NPC:
		var n := e as NPC
		if n.has_method("change_state"):
			n.change_state(NPCStateNames.IDLE)
			return
		play_cutscene_visual(false, dir)
		return


func _get_current_facing_dir() -> Vector2:
	var e := get_entity()
	if e == null or not is_instance_valid(e):
		return Vector2.DOWN

	if e is Player:
		var p := e as Player
		if "raycell_component" in p and p.raycell_component != null:
			return p.raycell_component.facing_dir
		return Vector2.DOWN

	if e is NPC:
		return (e as NPC).facing_dir

	if "facing_dir" in e:
		return e.facing_dir

	return Vector2.DOWN


func _get_move_tween_map(create_if_missing: bool) -> Dictionary:
	var loop := Engine.get_main_loop()
	if loop == null:
		return {}
	if not loop.has_meta(_MOVE_TWEEN_META_KEY):
		if not create_if_missing:
			return {}
		loop.set_meta(_MOVE_TWEEN_META_KEY, {})
	var d_any: Variant = loop.get_meta(_MOVE_TWEEN_META_KEY)
	return d_any if d_any is Dictionary else {}


func _set_move_tween_map(d: Dictionary) -> void:
	var loop := Engine.get_main_loop()
	if loop == null:
		return
	loop.set_meta(_MOVE_TWEEN_META_KEY, d)


func _quantize_to_cardinal(v: Vector2) -> Vector2:
	if abs(v.x) >= abs(v.y):
		return Vector2.RIGHT if v.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y >= 0.0 else Vector2.UP


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
