extends GameState


func enter(_prev: StringName = &"") -> void:
	# Force-close overlays and enter full pause dialogue mode.
	if flow == null:
		return
	flow.hide_all_menus()
	flow.set_hotbar_visible(false)
	flow.set_player_input_enabled(false)
	flow.set_npc_controllers_enabled(false)
	if TimeManager != null:
		TimeManager.pause(&"dialogue")
	flow.get_tree().paused = true


func exit(_next: StringName = &"") -> void:
	if TimeManager != null:
		TimeManager.resume(&"dialogue")
