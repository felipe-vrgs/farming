extends GameState

## GRANT_REWARD state
## - Temporarily pauses the game and shows a reward presentation UI
## - Always returns to gameplay (IN_GAME)

const _REWARD_PRESENTATION_SCREEN := 10  # UIManager.ScreenName.REWARD_PRESENTATION
const _SFX_REWARD := preload("res://assets/sounds/effects/win.wav")

var _player: Player = null
var _player_cutscene_comp: CutsceneActorComponent = null
var _held_item_tween: Tween = null


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE

	# Close on confirm/cancel style inputs.
	if (
		event.is_action_pressed(&"ui_accept")
		or event.is_action_pressed(&"ui_cancel")
		or event.is_action_pressed(&"pause")
		or event.is_action_pressed(&"open_player_menu")
	):
		return GameStateNames.IN_GAME

	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	if flow == null:
		return

	# Freeze gameplay but keep GameFlow running so it can receive input to close.
	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(&"grant_reward")

	GameplayUtils.set_hotbar_visible(false)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), false)

	# Consume rewards (best-effort; callers may push different shapes).
	var rows: Array = []
	if flow.has_method("consume_grant_reward_rows"):
		rows = flow.call("consume_grant_reward_rows") as Array

	# Best-effort: choose a primary icon from the first row.
	var icon: Texture2D = null
	if rows != null and not rows.is_empty():
		icon = _extract_icon(rows[0])

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
		var node := UIManager.show_screen(_REWARD_PRESENTATION_SCREEN)
		if node != null and node.has_method("show_prompt"):
			node.call("show_prompt", &"ui_accept", "New item unlocked")

	if SFXManager != null:
		SFXManager.play_ui(_SFX_REWARD, _player.global_position)


func exit(_next: StringName = &"") -> void:
	# Restore time (tree pause is controlled by the next state).
	if TimeManager != null:
		TimeManager.resume(&"grant_reward")

	if UIManager != null:
		var node: Node = null
		if UIManager.has_method("get_screen_node"):
			node = UIManager.call("get_screen_node", _REWARD_PRESENTATION_SCREEN) as Node
		if node != null and node.has_method("hide_prompt"):
			node.call("hide_prompt")
		UIManager.hide_screen(_REWARD_PRESENTATION_SCREEN)

	# Restore player visuals.
	if _player != null and is_instance_valid(_player):
		_restore_player_idle_front()
		_player.set_carried_item(null)
	# Intentionally keep the player facing the camera after returning to IN_GAME.
	_player = null
	_player_cutscene_comp = null
	_held_item_tween = null


func _bind_player() -> void:
	_player = null
	_player_cutscene_comp = null

	var p: Player = null
	if is_instance_valid(AgentBrain) and AgentBrain.has_method("get_agent_node"):
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

	if _player == null or not is_instance_valid(_player):
		return
	if _player.state_machine != null and is_instance_valid(_player.state_machine):
		_player.state_machine.change_state(PlayerStateNames.IDLE)

	if _player.animated_sprite != null and _player.animated_sprite.sprite_frames != null:
		if _player.animated_sprite.sprite_frames.has_animation("idle_front"):
			_player.animated_sprite.play("idle_front")

	if "carried_item_sprite" in _player and _player.carried_item_sprite != null:
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

	spr.scale = Vector2.ONE * 0.6
	spr.modulate = Color(1, 1, 1, 1)

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


func _extract_icon(entry: Variant) -> Texture2D:
	# Supports both the quest UI display model and older dictionary-style payloads.
	var icon: Texture2D = null
	if entry == null:
		pass
	elif entry is QuestUiHelper.ItemCountDisplay:
		icon = (entry as QuestUiHelper.ItemCountDisplay).icon
	elif entry is ItemData:
		icon = (entry as ItemData).icon
	elif entry is Dictionary:
		var d := entry as Dictionary
		var icon_any: Variant = d.get("icon")
		if icon_any is Texture2D:
			icon = icon_any as Texture2D
		else:
			var item_any: Variant = d.get("item_data")
			if item_any is ItemData:
				icon = (item_any as ItemData).icon
			else:
				var item_id_any: Variant = d.get("item_id")
				if item_id_any is StringName:
					var res := QuestUiHelper.resolve_item_data(item_id_any as StringName)
					icon = res.icon if res != null else null
	return icon
