extends GameState


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE
	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED
	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	# Force-close overlays and enter cutscene mode (tree running, controllers locked).
	if flow == null:
		return
	if UIManager != null:
		UIManager.hide_all_menus()
		UIManager.dismiss_quest_notifications()
	GameplayUtils.set_hotbar_visible(false)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_player_action_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), false)
	if TimeManager != null:
		TimeManager.pause(&"cutscene")
	# Ensure the tree is running so cutscene scripts can drive motion.
	flow.get_tree().paused = false
	GameplayUtils.fade_vignette_in(0.15)


func on_reveal(_overlay: StringName) -> void:
	enter()


func exit(_next: StringName = &"") -> void:
	if TimeManager != null:
		TimeManager.resume(&"cutscene")
	if flow != null:
		GameplayUtils.set_player_action_input_enabled(flow.get_tree(), true)
	GameplayUtils.fade_vignette_out(0.15)
