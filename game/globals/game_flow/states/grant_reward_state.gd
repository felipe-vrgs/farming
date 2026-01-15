extends GameState

## GRANT_REWARD state
## - Temporarily pauses the game and shows a reward presentation UI
## - Always returns to gameplay (IN_GAME)

const _REWARD_PRESENTATION_SCREEN := 10  # UIManager.ScreenName.REWARD_PRESENTATION
const _SFX_REWARD := preload("res://assets/sounds/effects/win.wav")
const _REWARD_ITEM_SHINE_SHADER: Shader = preload("res://game/ui/reward/reward_item_shine.gdshader")

var _player: Player = null
var _player_cutscene_comp: CutsceneActorComponent = null
var _held_item_tween: Tween = null
var _held_item_shine_tween: Tween = null
var _held_item_original_material: Material = null
var _held_item_shine_material: ShaderMaterial = null
var _held_item_original_material_captured: bool = false
var _return_state: StringName = GameStateNames.IN_GAME


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	# Pause overlay should return to grant reward on resume.
	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED
	# Close grant reward on player-menu inputs.
	if check_player_menu_input(event):
		return _return_state
	# Close on confirm input.
	if event.is_action_pressed(&"ui_accept"):
		return _return_state

	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	if flow == null:
		return

	_return_state = flow.consume_grant_reward_return_state()
	if String(_return_state).is_empty():
		_return_state = GameStateNames.IN_GAME

	# Freeze gameplay but keep GameFlow running so it can receive input to close.
	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(&"grant_reward")

	GameplayUtils.set_hotbar_visible(false)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), false)

	# Consume rewards (strict typed payload).
	var rows: Array[GrantRewardRow] = flow.consume_grant_reward_rows()
	if rows == null or rows.is_empty():
		return

	# Primary icon + title from the first row.
	var icon: Texture2D = rows[0].icon
	var title: String = rows[0].title

	# Face camera + show held item overhead.
	_bind_player()
	if _player_cutscene_comp != null:
		_player_cutscene_comp.face_toward(_player.global_position + Vector2.DOWN, true)
	elif _player != null and is_instance_valid(_player) and _player.raycell_component != null:
		_player.raycell_component.facing_dir = Vector2.DOWN
		# Refresh idle visuals via state machine if available.
		if _player.state_machine != null:
			_player.state_machine.change_state(PlayerStateNames.IDLE)

	if _player != null and is_instance_valid(_player):
		if icon != null:
			var held := ItemData.new()
			held.icon = icon
			_player.set_carried_item(held)
		else:
			_player.set_carried_item(null)
		_force_player_carry_idle_front()
		_animate_held_item_focus()

	if UIManager != null:
		UIManager.hide_all_menus()
		var node := UIManager.show_screen(_REWARD_PRESENTATION_SCREEN) as RewardPresentation
		if node != null:
			node.show_prompt(&"ui_accept", title)

	if SFXManager != null:
		SFXManager.play_ui(_SFX_REWARD, _player.global_position)


func exit(_next: StringName = &"") -> void:
	# Restore time (tree pause is controlled by the next state).
	if TimeManager != null:
		TimeManager.resume(&"grant_reward")

	if UIManager != null:
		var node := UIManager.get_screen_node(_REWARD_PRESENTATION_SCREEN) as RewardPresentation
		if node != null:
			node.hide_prompt()
		UIManager.hide_screen(_REWARD_PRESENTATION_SCREEN)

	# Restore player visuals.
	if _player != null and is_instance_valid(_player):
		_restore_player_idle_front()
		_player.set_carried_item(null)
	# Intentionally keep the player facing the camera after returning to IN_GAME.
	_player = null
	_player_cutscene_comp = null
	_held_item_tween = null
	_held_item_shine_tween = null
	_held_item_original_material = null
	_held_item_shine_material = null
	_held_item_original_material_captured = false


func _bind_player() -> void:
	_player = null
	_player_cutscene_comp = null

	var p: Player = null
	if is_instance_valid(AgentBrain):
		p = AgentBrain.get_agent_node(&"player") as Player
	if p == null:
		p = flow.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	_player = p

	if _player != null and is_instance_valid(_player):
		var comp_any := _player.get_node_or_null(NodePath("Components/CutsceneActorComponent"))
		if comp_any == null:
			comp_any = _player.get_node_or_null(NodePath("CutsceneActorComponent"))
		if comp_any is CutsceneActorComponent:
			_player_cutscene_comp = comp_any as CutsceneActorComponent


func _force_player_carry_idle_front() -> void:
	# Force the "hands up" pose during the reward moment.
	if _player == null or not is_instance_valid(_player):
		return
	# Prefer modular visuals if present.
	if "character_visual" in _player and _player.character_visual != null:
		_player.character_visual.play_directed(&"carry_idle", Vector2.DOWN)
		var clock := _player.character_visual.get_clock_sprite()
		if clock != null:
			clock.stop()
			clock.frame = 0
		return

	if _player.animated_sprite == null or _player.animated_sprite.sprite_frames == null:
		return

	var anim := "carry_idle_front"
	if _player.animated_sprite.sprite_frames.has_animation(anim):
		_player.animated_sprite.play(anim)
		# Tree is paused, so stop on the first frame (static pose).
		_player.animated_sprite.stop()
		_player.animated_sprite.frame = 0


func _restore_player_idle_front() -> void:
	# Ensure we return to a normal idle pose (no carry) after the reward moment.
	if _held_item_tween != null and is_instance_valid(_held_item_tween):
		_held_item_tween.kill()
		_held_item_tween = null
	if _held_item_shine_tween != null and is_instance_valid(_held_item_shine_tween):
		_held_item_shine_tween.kill()
		_held_item_shine_tween = null

	if _player == null or not is_instance_valid(_player):
		return
	if _player.state_machine != null and is_instance_valid(_player.state_machine):
		_player.state_machine.change_state(PlayerStateNames.IDLE)

	if "character_visual" in _player and _player.character_visual != null:
		_player.character_visual.play_directed(&"idle", Vector2.DOWN)
	elif _player.animated_sprite != null and _player.animated_sprite.sprite_frames != null:
		if _player.animated_sprite.sprite_frames.has_animation("idle_front"):
			_player.animated_sprite.play("idle_front")

	if "carried_item_sprite" in _player and _player.carried_item_sprite != null:
		if (
			_held_item_original_material_captured
			and _held_item_shine_material != null
			and is_instance_valid(_held_item_shine_material)
			and _player.carried_item_sprite.material == _held_item_shine_material
		):
			# Restore even if original was null.
			_player.carried_item_sprite.material = _held_item_original_material
		_held_item_original_material = null
		_held_item_shine_material = null
		_held_item_original_material_captured = false
		_player.carried_item_sprite.scale = Vector2.ONE
		_player.carried_item_sprite.modulate = Color(1, 1, 1, 1)


func _animate_held_item_focus() -> void:
	# Give the held icon a small "pop", then keep a gentle pulse for the whole state.
	if _player == null or not is_instance_valid(_player):
		return
	if not ("carried_item_sprite" in _player):
		return
	var spr: Sprite2D = _player.carried_item_sprite
	if spr == null or not is_instance_valid(spr) or not spr.visible:
		return

	if _held_item_tween != null and is_instance_valid(_held_item_tween):
		_held_item_tween.kill()
	if _held_item_shine_tween != null and is_instance_valid(_held_item_shine_tween):
		_held_item_shine_tween.kill()
		_held_item_shine_tween = null

	spr.scale = Vector2.ONE * 0.6
	spr.modulate = Color(1, 1, 1, 1)

	# Shader-based glow + sweep shine (pause-safe).
	# Keep headless tests deterministic and avoid shader/material churn.
	if OS.get_environment("FARMING_TEST_MODE") != "1" and _REWARD_ITEM_SHINE_SHADER != null:
		# If we're re-entering setup, make sure we don't accidentally treat our own
		# previous shine material as the "original".
		if (
			_held_item_original_material_captured
			and _held_item_shine_material != null
			and is_instance_valid(_held_item_shine_material)
			and spr.material == _held_item_shine_material
		):
			spr.material = _held_item_original_material

		_held_item_original_material = spr.material
		_held_item_original_material_captured = true
		_held_item_shine_material = ShaderMaterial.new()
		_held_item_shine_material.shader = _REWARD_ITEM_SHINE_SHADER
		# Medium intensity defaults.
		_held_item_shine_material.set_shader_parameter("glow_strength", 0.0)
		_held_item_shine_material.set_shader_parameter("glow_size", 0.0)
		_held_item_shine_material.set_shader_parameter("sweep_strength", 1.05)
		_held_item_shine_material.set_shader_parameter("sweep_width", 0.18)
		_held_item_shine_material.set_shader_parameter("sweep_speed", 0.9)
		_held_item_shine_material.set_shader_parameter("sweep_angle", -0.75)
		spr.material = _held_item_shine_material

		# Sweep runs in shader time to avoid reset flashes.

	_held_item_tween = _player.create_tween()
	_held_item_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Initial pop.
	_held_item_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_held_item_tween.tween_property(spr, "scale", Vector2.ONE * 1.25, 0.18)
	_held_item_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_held_item_tween.tween_property(spr, "scale", Vector2.ONE * 1.08, 0.12)
	# Sustained pulse until the state ends (we kill the tween on exit).
	_held_item_tween.set_loops()  # infinite
	_held_item_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_held_item_tween.tween_property(spr, "scale", Vector2.ONE * 1.14, 0.55)
	_held_item_tween.tween_property(spr, "scale", Vector2.ONE * 1.08, 0.55)
