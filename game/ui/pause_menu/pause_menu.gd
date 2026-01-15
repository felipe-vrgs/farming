extends Control

@export var default_slot: String = "default"

@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_to_menu_button: Button = %QuitToMenuButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure we capture input above gameplay.
	mouse_filter = Control.MOUSE_FILTER_STOP

	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_to_menu_button:
		quit_to_menu_button.pressed.connect(_on_quit_to_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	_refresh_save_button()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			_refresh_save_button()


func _refresh_save_button() -> void:
	if save_button == null:
		return

	var can_save := true
	if Runtime != null:
		if Runtime.has_method("can_player_save"):
			can_save = bool(Runtime.call("can_player_save"))
		else:
			can_save = (Runtime.flow_state == Enums.FlowState.RUNNING)

	save_button.disabled = not can_save
	if not can_save:
		save_button.tooltip_text = "Cannot save during cutscenes, dialogue, or sleep."
	else:
		save_button.tooltip_text = ""


func _on_resume_pressed() -> void:
	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.resume_game()


func _on_save_pressed() -> void:
	if UIManager == null:
		return

	var node := UIManager.show(UIManager.ScreenName.LOAD_GAME_MENU)
	if node is LoadGameMenu:
		(node as LoadGameMenu).set_mode(LoadGameMenu.MenuMode.SAVE, UIManager.ScreenName.PAUSE_MENU)
	elif node != null and node.has_method("set_mode"):
		node.call("set_mode", LoadGameMenu.MenuMode.SAVE, UIManager.ScreenName.PAUSE_MENU)

	UIManager.hide(UIManager.ScreenName.PAUSE_MENU)


func _on_load_pressed() -> void:
	if UIManager == null:
		return

	var node := UIManager.show(UIManager.ScreenName.LOAD_GAME_MENU)
	if node is LoadGameMenu:
		(node as LoadGameMenu).set_mode(LoadGameMenu.MenuMode.LOAD, UIManager.ScreenName.PAUSE_MENU)
	elif node != null and node.has_method("set_mode"):
		node.call("set_mode", LoadGameMenu.MenuMode.LOAD, UIManager.ScreenName.PAUSE_MENU)

	UIManager.hide(UIManager.ScreenName.PAUSE_MENU)


func _on_quit_to_menu_pressed() -> void:
	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.quit_to_menu()


func _on_quit_pressed() -> void:
	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.quit_game()


func _on_settings_pressed() -> void:
	if UIManager != null:
		UIManager.show(UIManager.ScreenName.SETTINGS_MENU)
