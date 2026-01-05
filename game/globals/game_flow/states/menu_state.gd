extends GameState


func enter(_prev: StringName = &"") -> void:
	if flow == null:
		return

	flow.force_unpaused()
	if UIManager != null:
		UIManager.hide_all_menus()

	if Runtime != null:
		Runtime.autosave_session()
	if DialogueManager != null:
		DialogueManager.stop_dialogue()
	if EventBus != null and flow.active_level_id != Enums.Levels.NONE:
		EventBus.active_level_changed.emit(flow.active_level_id, Enums.Levels.NONE)

	flow.get_tree().change_scene_to_file("res://main.tscn")
	if UIManager != null and UIManager.has_method("show"):
		UIManager.show(UIManager.ScreenName.MAIN_MENU)
