class_name Player
extends CharacterBody2D

@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize Input Map
	var input_config = PlayerInputConfig.new()
	input_config.ensure_actions_registered()
	# Initialize State Machine
	state_machine.init()

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)
	move_and_slide()

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)
