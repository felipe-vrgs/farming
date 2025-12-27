class_name Player
extends CharacterBody2D

@export var player_balance_config: PlayerBalanceConfig
@export var player_input_config: PlayerInputConfig
@export var inventory: InventoryData

## How far in front of the player we consider "interactable" (in pixels).
@export var interact_distance: float = 12.0
## Minimum time (in seconds) between tool uses.
@export var tool_cooldown: float = 0.2

var tool_shovel: ToolData = preload("res://entities/tools/data/shovel.tres")
var tool_water: ToolData = preload("res://entities/tools/data/watering_can.tres")
var tool_seeds: ToolData = preload("res://entities/tools/data/seeds.tres")
var tool_axe: ToolData = preload("res://entities/tools/data/axe.tres")
var tool_hand: ToolData = preload("res://entities/tools/data/hand.tres")

var hotbar_assignments: Array = []

var available_seeds: Dictionary[StringName, PlantData] = {
	"tomato": preload("res://entities/plants/types/tomato.tres"),
}

var _current_seed: StringName = "tomato"
var _tool_cooldown_timer: float = 0.0

@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var interact_ray: RayCast2D = $InteractRay
@onready var interactivity_manager: InteractivityManager = $Components/InteractivityManager
@onready var sprite_shake_component: ShakeComponent = $Components/SpriteShakeComponent
@onready var tool_node: HandTool = $Components/Tool
@onready var camera_shake_component: ShakeComponent = $Components/CameraShakeComponent
@onready var feet_marker: Marker2D = $Markers/Feet

func _ready() -> void:
	add_to_group("player")
	if inventory == null:
		inventory = preload("res://entities/player/player_inventory.tres")

	hotbar_assignments = [tool_shovel, tool_seeds, tool_water, tool_axe, tool_hand]

	if tool_node.data == null:
		_equip_tool(tool_hand) # Default to hand

	# Initialize Input Map
	player_input_config.ensure_actions_registered()

	# Connect to state machine binding request
	state_machine.state_binding_requested.connect(_on_state_binding_requested)

	# Initialize State Machine
	state_machine.init()

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)
	interactivity_manager.update_aim(self)
	# Use the feet marker to update the player position so that the player is always on the ground
	GridState.update_player_position(feet_marker.global_position)
	move_and_slide()

func _process(delta: float) -> void:
	if _tool_cooldown_timer > 0:
		_tool_cooldown_timer -= delta
	state_machine.process_frame(delta)

func can_use_tool() -> bool:
	return _tool_cooldown_timer <= 0.0

func start_tool_cooldown(duration: float = -1.0) -> void:
	if duration < 0:
		_tool_cooldown_timer = tool_cooldown
	else:
		_tool_cooldown_timer = duration

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(player_input_config.action_hotbar_1):
		_equip_tool_at_index(0)
		return

	if event.is_action_pressed(player_input_config.action_hotbar_2):
		_equip_tool_at_index(1)
		return

	if event.is_action_pressed(player_input_config.action_hotbar_3):
		_equip_tool_at_index(2)
		return

	if event.is_action_pressed(player_input_config.action_hotbar_4):
		_equip_tool_at_index(3)
		return

	# Add a way to switch back to hand (e.g. Escape or 0, or just toggle)
	if event.is_action_pressed("ui_cancel"): # Temporary mapping
		_equip_tool_at_index(4)
		return

	state_machine.process_input(event)

func _equip_tool_at_index(index: int) -> void:
	if index < 0 or index >= hotbar_assignments.size():
		return

	var item = hotbar_assignments[index]

	if item == tool_seeds:
		_cycle_seeds()
		return

	if item is ToolData:
		_equip_tool(item)

func _equip_tool(data: ToolData) -> void:
	tool_node.data = data
	EventBus.player_tool_equipped.emit(data)
	print("Equipped: ", tool_node.data.display_name)

func _cycle_seeds() -> void:
	if available_seeds.is_empty():
		return

	var keys = available_seeds.keys()
	if tool_node.data != tool_seeds:
		# Just equip the first/current one
		_apply_seed_selection()
	else:
		# Cycle to next key
		var idx = keys.find(_current_seed)
		_current_seed = keys[(idx + 1) % keys.size()]
		_apply_seed_selection()

func _apply_seed_selection() -> void:
	var plant_res = available_seeds[_current_seed]
	var plant = plant_res as PlantData

	if not plant:
		push_error("Selected seed is not a valid PlantData resource: %s" % plant_res)
		return

	if tool_seeds.behavior is SeedBehavior:
		tool_seeds.behavior.plant_id = plant.resource_path
		tool_seeds.display_name = plant.plant_name + " Seeds"

	_equip_tool(tool_seeds)

func _on_state_binding_requested(state: State) -> void:
	state.bind_parent(self)
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
		collision_mask = TERRAIN_BIT | GUARDRAILS_BIT  # 6
	else:
		collision_mask = GUARDRAILS_BIT  # 4

func recoil() -> void:
	if sprite_shake_component:
		sprite_shake_component.start_shake()

	if camera_shake_component:
		camera_shake_component.start_shake()
