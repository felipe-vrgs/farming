class_name NPC
extends CharacterBody2D

@export var inventory: InventoryData = null
@export var move_speed: float = 22.0
@export var npc_config: NpcConfig = null:
	get:
		return _npc_config
	set(value):
		_npc_config = value
		# Apply immediately if we already have onready refs.
		if is_node_ready():
			_apply_npc_config()

## Last facing direction (used by states to pick directed idle animations).
var facing_dir: Vector2 = Vector2.DOWN

var money: int = 0
var route_blocked_by_player: bool = false
var route_override_id: RouteIds.Id = RouteIds.Id.NONE
var route_looping: bool = true

var _npc_config: NpcConfig = null
var _state_machine_initialized: bool = false
var _player_blocker_count: int = 0

@onready var state_machine: StateMachine = $StateMachine
@onready var agent_component: AgentComponent = $Components/AgentComponent
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Avoid mutating shared `.tres` resources from `res://`.
	if inventory != null and String(inventory.resource_path).begins_with("res://"):
		inventory = inventory.duplicate(true)

	# Connect to state machine binding request (mirror Player).
	if state_machine != null:
		state_machine.state_binding_requested.connect(_on_state_binding_requested)
		# Defer initialization so spawners can place us first (fixes "snap to route start" on reload).
		call_deferred("_init_state_machine")

	_apply_npc_config()

func _init_state_machine() -> void:
	if _state_machine_initialized:
		return
	if state_machine == null or not is_instance_valid(state_machine):
		return
	state_machine.init()
	_state_machine_initialized = true

func _physics_process(delta: float) -> void:
	# During scene transitions / hydration, the NPC can be queued-freed.
	# Avoid touching freed components.
	if not is_inside_tree():
		return
	if state_machine == null or not is_instance_valid(state_machine):
		return

	state_machine.process_physics(delta)
	move_and_slide()

func _process(delta: float) -> void:
	if state_machine == null or not is_instance_valid(state_machine):
		return
	state_machine.process_frame(delta)

func set_npc_config(cfg: NpcConfig) -> void:
	npc_config = cfg

func change_state(state_name: StringName) -> void:
	if state_machine == null or not is_instance_valid(state_machine):
		return
	state_machine.change_state(state_name)

func _on_state_binding_requested(state: State) -> void:
	state.bind_parent(self)
	state.animation_change_requested.connect(_on_animation_change_requested)

func _on_animation_change_requested(animation_name: StringName) -> void:
	# States emit fully-resolved animation names; host just plays them.
	if sprite == null or sprite.sprite_frames == null:
		return
	if String(animation_name).is_empty():
		return
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.animation != animation_name:
		sprite.play(animation_name)

func _on_player_blocker_area_body_entered(body: Node) -> void:
	if body != null and body.is_in_group(Groups.PLAYER):
		_player_blocker_count += 1
	route_blocked_by_player = _player_blocker_count > 0

func _on_player_blocker_area_body_exited(body: Node) -> void:
	if body != null and body.is_in_group(Groups.PLAYER):
		_player_blocker_count = max(0, _player_blocker_count - 1)
	route_blocked_by_player = _player_blocker_count > 0

func _apply_npc_config() -> void:
	var cfg := _npc_config
	if cfg == null:
		return

	# Identity (stable + persisted in AgentRecord)
	if agent_component != null and not String(cfg.npc_id).is_empty():
		agent_component.agent_id = cfg.npc_id
		agent_component.kind = Enums.AgentKind.NPC

	# Visuals (purely presentation; not persisted)
	if cfg.sprite_frames != null and sprite != null:
		sprite.sprite_frames = cfg.sprite_frames

	if sprite != null and not String(cfg.default_animation).is_empty():
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(cfg.default_animation):
			sprite.play(cfg.default_animation)

	# Movement policy is delegated to NPC states (idle / follow_route / etc).
	if cfg.move_speed > 0.0:
		move_speed = cfg.move_speed

func apply_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	money = int(rec.money)

func capture_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	rec.money = int(money)
