class_name Player
extends CharacterBody2D

@export var player_balance_config: PlayerBalanceConfig
@export var player_input_config: PlayerInputConfig
@export var inventory: InventoryData

var input_enabled: bool = true

@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var raycell_component: RayCellComponent = $Components/RayCellComponent
@onready var sprite_shake_component: ShakeComponent = $Components/SpriteShakeComponent
@onready var tool_node: HandTool = $Components/Tool
@onready var tool_manager: ToolManager = $Components/ToolManager
@onready var camera_shake_component: ShakeComponent = $Components/CameraShakeComponent

func _ready() -> void:
	add_to_group(Groups.PLAYER)
	if inventory == null:
		inventory = preload("res://entities/player/player_inventory.tres")

	# Avoid mutating shared `.tres` resources from `res://` (inventory should be per-session).
	if inventory != null and String(inventory.resource_path).begins_with("res://"):
		inventory = inventory.duplicate(true)

	# Initialize Input Map
	player_input_config.ensure_actions_registered()

	# Connect to state machine binding request
	state_machine.state_binding_requested.connect(_on_state_binding_requested)

	z_index = 15;

	# Initialize State Machine
	state_machine.init()

func _physics_process(delta: float) -> void:
	# During scene transitions / hydration, the player can be queued-freed.
	# Avoid touching freed components.
	if not is_inside_tree():
		return
	if raycell_component == null or not is_instance_valid(raycell_component):
		return
	if state_machine == null or not is_instance_valid(state_machine):
		return

	if not input_enabled:
		move_and_slide()
		return

	state_machine.process_physics(delta)
	# Update the raycell component with the player's velocity and position
	raycell_component.update_aim(velocity, global_position - Vector2.UP * 4)
	move_and_slide()

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return

	var index: int = -1
	if event.is_action_pressed(player_input_config.action_hotbar_1):
		index = 0

	if event.is_action_pressed(player_input_config.action_hotbar_2):
		index = 1

	if event.is_action_pressed(player_input_config.action_hotbar_3):
		index = 2

	if event.is_action_pressed(player_input_config.action_hotbar_4):
		index = 3

	if event.is_action_pressed(player_input_config.action_hotbar_5):
		index = 4

	if index >= 0:
		tool_manager.select_tool(index)
		return

	state_machine.process_input(event)

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not input_enabled:
		velocity = Vector2.ZERO
		if state_machine.current_state.name != PlayerStateNames.IDLE:
			state_machine.change_state(PlayerStateNames.IDLE)

func _on_state_binding_requested(state: State) -> void:
	state.bind_parent(self)
	state.animation_change_requested.connect(_on_animation_change_requested)

func _on_animation_change_requested(animation_name: StringName) -> void:
	if raycell_component == null or not is_instance_valid(raycell_component):
		return
	var dir_suffix := _direction_suffix(raycell_component.facing_dir)
	var directed := StringName(str(animation_name, "_", dir_suffix))

	if animated_sprite.animation == directed:
		return

	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(directed):
		animated_sprite.play(directed)
		return

	# Back-compat: if you still have old animations like "move_left" or "idle" only.
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
		return

	print("Missing animation: ", directed, " (and base: ", animation_name, ")")

func _direction_suffix(dir: Vector2) -> String:
	# Match your existing move_* convention.
	if abs(dir.x) >= abs(dir.y):
		# Godot: +X is right, -X is left.
		return "right" if dir.x > 0.0 else "left"
	return "front" if dir.y > 0.0 else "back"

func set_terrain_collision(enabled: bool) -> void:
	const TERRAIN_BIT := 1 << 1  # Layer 2
	const GUARDRAILS_BIT := 1 << 2  # Layer 3
	if enabled:
		collision_mask = TERRAIN_BIT | GUARDRAILS_BIT  # 6
	else:
		collision_mask = GUARDRAILS_BIT  # 4

func recoil() -> void:
	if sprite_shake_component:
		sprite_shake_component.start_shake()

	if camera_shake_component:
		camera_shake_component.start_shake()
