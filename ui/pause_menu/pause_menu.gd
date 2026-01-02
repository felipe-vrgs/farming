extends Control

signal resume_requested
signal save_requested(slot: String)
signal load_requested(slot: String)
signal quit_to_menu_requested
signal quit_requested

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
		resume_button.pressed.connect(func(): resume_requested.emit())
	if save_button:
		save_button.pressed.connect(func(): save_requested.emit(default_slot))
	if load_button:
		load_button.pressed.connect(func(): load_requested.emit(default_slot))
	if quit_to_menu_button:
		quit_to_menu_button.pressed.connect(func(): quit_to_menu_requested.emit())
	if quit_button:
		quit_button.pressed.connect(func(): quit_requested.emit())

