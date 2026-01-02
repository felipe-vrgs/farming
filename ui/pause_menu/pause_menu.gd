extends Control

@export var default_slot: String = "default"

@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var quit_to_menu_button: Button = %QuitToMenuButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Ensure we capture input above gameplay.
	mouse_filter = Control.MOUSE_FILTER_STOP

	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if quit_to_menu_button:
		quit_to_menu_button.pressed.connect(_on_quit_to_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	if GameFlow != null:
		GameFlow.resume_game()

func _on_save_pressed() -> void:
	if GameFlow != null:
		GameFlow.save_game_to_slot(default_slot)

func _on_load_pressed() -> void:
	if GameFlow != null:
		GameFlow.load_game_from_slot(default_slot)

func _on_quit_to_menu_pressed() -> void:
	if GameFlow != null:
		GameFlow.quit_to_menu()

func _on_quit_pressed() -> void:
	if GameFlow != null:
		GameFlow.quit_game()

