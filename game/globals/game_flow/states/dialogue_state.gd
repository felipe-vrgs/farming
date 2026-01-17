extends GameState


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE
	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED
	if _handle_dialogue_skip_input(event):
		return GameStateNames.NONE
	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	# Force-close overlays and enter full pause dialogue mode.
	if flow == null:
		return
	if UIManager != null:
		UIManager.hide_all_menus()
		UIManager.dismiss_quest_notifications()
		UIManager.show(UIManager.ScreenName.EMOTE_OVERLAY)
	GameplayUtils.set_hotbar_visible(false)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), false)
	if TimeManager != null:
		TimeManager.pause(&"dialogue")
	flow.get_tree().paused = true


func on_reveal(_overlay: StringName) -> void:
	enter()


func exit(_next: StringName = &"") -> void:
	if TimeManager != null:
		TimeManager.resume(&"dialogue")


func _handle_dialogue_skip_input(event: InputEvent) -> bool:
	if event == null:
		return false
	var action_setting = ProjectSettings.get_setting(
		"dialogic/text/input_action", "dialogic_default_action"
	)
	var action := StringName(str(action_setting))
	if action.is_empty() or not event.is_action_pressed(action):
		return false
	if Dialogic == null:
		return false
	if Dialogic.current_state != DialogicGameHandler.States.REVEALING_TEXT:
		return false
	if not Dialogic.Text.is_text_reveal_skippable():
		return false
	Dialogic.Text.skip_text_reveal()
	if Dialogic.has_subsystem("Inputs"):
		Dialogic.Inputs.action_was_consumed = true
		Dialogic.Inputs.stop_timers()
	return true
