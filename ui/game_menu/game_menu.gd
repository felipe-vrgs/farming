extends Control

const LOAD_GAME_MENU_SCENE = preload("res://ui/game_menu/load_game_menu.tscn")

@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var load_game_button: Button = $CenterContainer/VBoxContainer/LoadGameButton

func _ready() -> void:
	$CenterContainer/VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	$CenterContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	if SaveManager:
		# Continue is enabled if there's an active session
		continue_button.disabled = (SaveManager.load_session_game_save() == null)
		# Load Game is enabled if there are any slots
		var slots = SaveManager.list_slots()
		load_game_button.disabled = slots.is_empty()

func _on_new_game_pressed() -> void:
	if GameManager:
		GameManager.start_new_game()

func _on_continue_pressed() -> void:
	if GameManager:
		GameManager.continue_session()

func _on_load_game_pressed() -> void:
	var menu = LOAD_GAME_MENU_SCENE.instantiate()
	add_child(menu)
	# Optional: hide main menu buttons?
	# For now, just overlay.

func _on_quit_pressed() -> void:
	get_tree().quit()
