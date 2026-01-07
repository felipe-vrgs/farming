extends GameState


func handle_unhandled_input(event: InputEvent) -> StringName:
	if flow == null or event == null:
		return GameStateNames.NONE
	if event.is_action_pressed(&"pause"):
		return GameStateNames.PAUSED
	return GameStateNames.NONE


func enter(_prev: StringName = &"") -> void:
	# Force-close overlays and enter full pause dialogue mode.
	if flow == null:
		return
	if UIManager != null:
		UIManager.hide_all_menus()
	GameplayUtils.set_hotbar_visible(false)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)
	GameplayUtils.set_npc_controllers_enabled(flow.get_tree(), false)
	if TimeManager != null:
		TimeManager.pause(&"dialogue")
	flow.get_tree().paused = true


func exit(_next: StringName = &"") -> void:
	if TimeManager != null:
		TimeManager.resume(&"dialogue")
