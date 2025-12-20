class_name Player
extends CharacterBody2D

@export var player_balance_config: PlayerBalanceConfig
@export var player_input_config: PlayerInputConfig

@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize Input Map
	player_input_config.ensure_actions_registered()

	# Connect to state machine binding request
	state_machine.state_binding_requested.connect(_on_state_binding_requested)

	# Initialize State Machine
	state_machine.init()

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)
	move_and_slide()

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)

func _on_state_binding_requested(state: State) -> void:
	state.bind_player(self)
	state.animation_change_requested.connect(_on_animation_change_requested)

func _on_animation_change_requested(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

## Toggle collision with Terrain layer (layer 2).
## GuardRails (layer 3) always collide.
func set_terrain_collision(enabled: bool) -> void:
	const TERRAIN_BIT := 1 << 1  # Layer 2
	const GUARDRAILS_BIT := 1 << 2  # Layer 3
	if enabled:
		z_index = 15
		collision_mask = TERRAIN_BIT | GUARDRAILS_BIT  # 6
	else:
		z_index = 35  # Above Decor (30), below future overlays
		collision_mask = GUARDRAILS_BIT  # 4
