extends GameState


func enter(_prev: StringName = &"") -> void:
	# Force-close overlays and enter cutscene mode (tree running, controllers locked).
	if flow == null:
		return
	flow.hide_all_menus()
	flow.set_hotbar_visible(false)
	flow.set_player_input_enabled(false)
	flow.set_npc_controllers_enabled(false)
	if TimeManager != null:
		TimeManager.pause(&"cutscene")
	# Ensure the tree is running so cutscene scripts can drive motion.
	flow.get_tree().paused = false
	flow.fade_vignette_in(0.15)


func exit(_next: StringName = &"") -> void:
	if TimeManager != null:
		TimeManager.resume(&"cutscene")
	if flow != null:
		flow.fade_vignette_out(0.15)
