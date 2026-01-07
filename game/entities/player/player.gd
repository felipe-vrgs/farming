class_name Player
extends CharacterBody2D

@export var player_balance_config: PlayerBalanceConfig
@export var player_input_config: PlayerInputConfig
@export var inventory: InventoryData

var money: int = 0
var input_enabled: bool = true

@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var footsteps_component: FootstepsComponent = $Components/FootstepsComponent
@onready var raycell_component: RayCellComponent = $Components/RayCellComponent
@onready var sprite_shake_component: ShakeComponent = $Components/SpriteShakeComponent
@onready var tool_node: HandTool = $Components/Tool
@onready var tool_manager: ToolManager = $Components/ToolManager
@onready var placement_manager = $Components/PlacementManager
@onready var camera_shake_component: ShakeComponent = $Components/CameraShakeComponent
@onready var carried_item_sprite: Sprite2D = $Carry/CarriedItem


func _ready() -> void:
	add_to_group(Groups.PLAYER)
	if inventory == null:
		inventory = preload("res://game/entities/player/player_inventory.tres")

	# Avoid mutating shared `.tres` resources from `res://` (inventory should be per-session).
	if inventory != null and String(inventory.resource_path).begins_with("res://"):
		inventory = inventory.duplicate(true)

	# Initialize Input Map
	player_input_config.ensure_actions_registered()

	# Connect to state machine binding request
	state_machine.state_binding_requested.connect(_on_state_binding_requested)

	ZLayers.apply_world_entity(self)

	# Initialize State Machine
	state_machine.init()

	# Start with no carried item visual.
	set_carried_item(null)


func set_carried_item(item: ItemData) -> void:
	# Visual layer for "holding item overhead".
	if carried_item_sprite != null:
		if item != null and item.icon is Texture2D:
			carried_item_sprite.texture = item.icon
			carried_item_sprite.visible = true
		else:
			carried_item_sprite.texture = null
			carried_item_sprite.visible = false

	# Hide hand tool while carrying a non-tool item.
	if tool_node != null:
		tool_node.visible = item == null or item is ToolData


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
	var actions := [
		player_input_config.action_hotbar_1,
		player_input_config.action_hotbar_2,
		player_input_config.action_hotbar_3,
		player_input_config.action_hotbar_4,
		player_input_config.action_hotbar_5,
		player_input_config.action_hotbar_6,
		player_input_config.action_hotbar_7,
		player_input_config.action_hotbar_8,
		player_input_config.action_hotbar_9,
		player_input_config.action_hotbar_0,
	]
	for i in range(actions.size()):
		if event.is_action_pressed(actions[i]):
			index = i
			break

	if index >= 0:
		if tool_manager != null and tool_manager.has_method("select_hotbar_slot"):
			tool_manager.call("select_hotbar_slot", index)
		else:
			# Back-compat (older ToolManager API).
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

	print("Missing animation: ", directed)


func _direction_suffix(dir: Vector2) -> String:
	# Match your existing move_* convention.
	if abs(dir.x) >= abs(dir.y):
		# Godot: +X is right, -X is left.
		return "right" if dir.x > 0.0 else "left"
	return "front" if dir.y > 0.0 else "back"


func set_terrain_collision(enabled: bool) -> void:
	const TERRAIN_BIT := 1 << 1  # Layer 2
	const GUARDRAILS_BIT := 1 << 2  # Layer 3
	const ITEMS_BIT := 1 << 4  # Layer 5 (WorldItem Area2D uses collision_layer=16)
	if enabled:
		collision_mask = TERRAIN_BIT | GUARDRAILS_BIT | ITEMS_BIT  # 22
	else:
		# Keep item pickup enabled even when terrain collision is disabled (wall pass zones, etc.).
		collision_mask = GUARDRAILS_BIT | ITEMS_BIT  # 20


func recoil() -> void:
	if sprite_shake_component:
		sprite_shake_component.start_shake()

	if camera_shake_component:
		camera_shake_component.start_shake()


func apply_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	if raycell_component != null:
		raycell_component.facing_dir = rec.facing_dir

	# If already idle, refresh animation to match new facing_dir
	if state_machine != null and state_machine.current_state != null:
		if String(state_machine.current_state.name).to_snake_case() == PlayerStateNames.IDLE:
			state_machine.change_state(PlayerStateNames.IDLE)


func capture_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	if raycell_component != null:
		rec.facing_dir = raycell_component.facing_dir
