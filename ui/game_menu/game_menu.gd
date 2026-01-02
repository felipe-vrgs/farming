extends Control

@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var load_game_button: Button = $CenterContainer/VBoxContainer/LoadGameButton

func _ready() -> void:
	$CenterContainer/VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	$CenterContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	if Runtime and Runtime.save_manager:
		# Continue is enabled if there's an active session
		continue_button.disabled = (Runtime.save_manager.load_session_game_save() == null)
		# Load Game is enabled if there are any slots
		var slots = Runtime.save_manager.list_slots()
		load_game_button.disabled = slots.is_empty()

func _on_new_game_pressed() -> void:
	if Runtime and Runtime.game_flow:
		await Runtime.game_flow.start_new_game()

func _on_continue_pressed() -> void:
	if Runtime and Runtime.game_flow:
		await Runtime.game_flow.continue_session()

func _on_load_game_pressed() -> void:
	if UIManager != null:
		if UIManager.has_method("show"):
			UIManager.show(UIManager.ScreenName.LOAD_GAME_MENU)
			return
		if UIManager.has_method("show_load_game_menu"):
			UIManager.show_load_game_menu()
			return

func _on_quit_pressed() -> void:
	get_tree().quit()
