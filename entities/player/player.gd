class_name Player
extends CharacterBody2D

@export var player_balance_config: PlayerBalanceConfig
@export var player_input_config: PlayerInputConfig
@export var equipped_tool: ToolData

## How far in front of the player we consider "interactable" (in pixels).
@export var interact_distance: float = 12.0

var tool_shovel: ToolData = preload("res://entities/tools/shovel.tres")
var tool_water: ToolData = preload("res://entities/tools/watering_can.tres")
var tool_seeds: ToolData = preload("res://entities/tools/seeds.tres")
var tool_axe: ToolData = preload("res://entities/tools/axe.tres")

var available_seeds: Dictionary[StringName, PlantData] = {
	"tomato": preload("res://entities/plants/types/tomato.tres"),
}

var _current_seed: StringName = "tomato"

@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_ray: RayCast2D = $InteractRay
@onready var interactivity_manager: InteractivityManager = $InteractivityManager
@onready var tool_hit_particles: ToolHitParticles = $ToolHitParticles

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if equipped_tool == null:
		_apply_seed_selection()

	# Initialize Input Map
	player_input_config.ensure_actions_registered()

	# Connect to state machine binding request
	state_machine.state_binding_requested.connect(_on_state_binding_requested)

	# Initialize State Machine
	state_machine.init()

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)
	interactivity_manager.update_aim(self)
	move_and_slide()

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

func _unhandled_input(event: InputEvent) -> void:
	# TODO: IMPROVE THIS
	# 1 = Shovel, 2 = Cycle Seeds, 3 = Watering Can, 4 = Axe
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				equipped_tool = tool_shovel
				print("Equipped: ", equipped_tool.display_name)
				return
			KEY_2, KEY_KP_2:
				_cycle_seeds()
				return
			KEY_3, KEY_KP_3:
				equipped_tool = tool_water
				print("Equipped: ", equipped_tool.display_name)
				return
			KEY_4, KEY_KP_4:
				equipped_tool = tool_axe
				print("Equipped: ", equipped_tool.display_name)
				return
	state_machine.process_input(event)

func _cycle_seeds() -> void:
	if available_seeds.is_empty():
		return

	var keys = available_seeds.keys()
	if equipped_tool != tool_seeds:
		# Just equip the first/current one
		_apply_seed_selection()
	else:
		# Cycle to next key
		var idx = keys.find(_current_seed)
		_current_seed = keys[(idx + 1) % keys.size()]
		_apply_seed_selection()

func _apply_seed_selection() -> void:
	var plant := available_seeds[_current_seed]
	if tool_seeds.behavior is SeedBehavior:
		tool_seeds.behavior.plant_id = plant.resource_path
		tool_seeds.display_name = plant.plant_name + " Seeds"

	equipped_tool = tool_seeds
	print("Equipped: ", equipped_tool.display_name)

func _on_state_binding_requested(state: State) -> void:
	state.bind_player(self)
	state.animation_change_requested.connect(_on_animation_change_requested)

func _on_animation_change_requested(animation_name: StringName) -> void:
	var dir_suffix := _direction_suffix(interactivity_manager.facing_dir)
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
		z_index = 15
		collision_mask = TERRAIN_BIT | GUARDRAILS_BIT  # 6
	else:
		z_index = 35  # Above Decor (30), below future overlays
		collision_mask = GUARDRAILS_BIT  # 4
