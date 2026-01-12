class_name NPC
extends CharacterBody2D

@export var inventory: InventoryData = null
@export var move_speed: float = 22.0
@export var debug_avoidance: bool = false
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

## Used by states to detect if blocked by player (for block reason reporting).
var route_blocked_by_player: bool = false

var _npc_config: NpcConfig = null
var _state_machine_initialized: bool = false
var _player_blocker_count: int = 0
var _player_blocker: Node2D = null
var _controller_enabled: bool = true

@onready var state_machine: StateMachine = $StateMachine
@onready var agent_component: AgentComponent = $Components/AgentComponent
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var footsteps_component: FootstepsComponent = $Components/FootstepsComponent
@onready var talk_component: TalkOnInteract = $Components/TalkOnInteract


func _enter_tree() -> void:
	# Ensure Runtime can disable controllers immediately on spawn (CUTSCENE mode),
	# even before _ready() runs.
	add_to_group(Groups.NPC_GROUP)
	# Extra safety: if we spawned during CUTSCENE/DIALOGUE, lock immediately so
	# NPC state machine can't continue walking toward a previous target.
	if Runtime == null:
		return
	if int(Runtime.flow_state) != int(Enums.FlowState.RUNNING):
		set_controller_enabled(false)


func _ready() -> void:
	# Avoid mutating shared `.tres` resources from `res://`.
	if inventory != null and String(inventory.resource_path).begins_with("res://"):
		inventory = inventory.duplicate(true)

	# Initialize State Machine
	if state_machine != null:
		state_machine.state_binding_requested.connect(_on_state_binding_requested)
		_init_state_machine()

	_apply_npc_config()


func _clear_debug() -> void:
	debug_avoidance = false
	_clear_avoidance_debug_lines()


func _clear_avoidance_debug_lines() -> void:
	# Avoidance debug lines are created as Line2D children by the avoiding state.
	# Clearing them here makes toggling debug deterministic (no need to wait for state ticks).
	var names := [
		"AvoidTarget",
		"AvoidForward",
		"AvoidChosen",
	]
	for n in names:
		var node := get_node_or_null(NodePath(n))
		if node is Line2D:
			(node as Line2D).queue_free()


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
	if not _controller_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if state_machine == null or not is_instance_valid(state_machine):
		return

	state_machine.process_physics(delta)
	move_and_slide()


func _process(delta: float) -> void:
	if not _controller_enabled:
		return
	if state_machine == null or not is_instance_valid(state_machine):
		return
	state_machine.process_frame(delta)


## Enable/disable NPC autonomous controller (AI/state machine).
## Used by Runtime flow states (CUTSCENE/DIALOGUE).
func set_controller_enabled(enabled: bool) -> void:
	_controller_enabled = enabled
	if not _controller_enabled:
		velocity = Vector2.ZERO
		if state_machine != null and state_machine.current_state != null:
			# Force idle visuals while locked.
			if String(state_machine.current_state.name).to_snake_case() != NPCStateNames.IDLE:
				state_machine.change_state(NPCStateNames.IDLE)


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
		if _player_blocker == null and body is Node2D:
			_player_blocker = body as Node2D
	route_blocked_by_player = _player_blocker_count > 0


func _on_player_blocker_area_body_exited(body: Node) -> void:
	if body != null and body.is_in_group(Groups.PLAYER):
		_player_blocker_count = max(0, _player_blocker_count - 1)
		if _player_blocker == body:
			_player_blocker = null
	route_blocked_by_player = _player_blocker_count > 0


## Direction pointing away from the player when they're blocking.
## Returns Vector2.ZERO if player not known.
func get_player_blocker_away_dir() -> Vector2:
	if _player_blocker == null or not is_instance_valid(_player_blocker):
		return Vector2.ZERO
	var away := global_position - _player_blocker.global_position
	if away.length() < 0.001:
		return Vector2.ZERO
	return away.normalized()


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
			if (
				sprite.sprite_frames != null
				and sprite.sprite_frames.has_animation(cfg.default_animation)
			):
				sprite.play(cfg.default_animation)

	# Movement policy is delegated to NPC states (idle / follow_route / etc).
	if cfg.move_speed > 0.0:
		move_speed = cfg.move_speed

	# Dialogue
	if talk_component != null and not String(cfg.dialogue_id).is_empty():
		talk_component.dialogue_id = cfg.dialogue_id


func apply_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return

	# If already idle, refresh animation to match new facing_dir
	if state_machine != null and state_machine.current_state != null:
		if String(state_machine.current_state.name).to_snake_case() == NPCStateNames.IDLE:
			state_machine.change_state(NPCStateNames.IDLE)
