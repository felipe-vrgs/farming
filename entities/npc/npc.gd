class_name NPC
extends CharacterBody2D

const _WAYPOINT_EPS := 2.0

@export var inventory: InventoryData = null
@export var move_speed: float = 22.0
@export var npc_config: NpcConfig = null:
	set(value):
		_npc_config = value
		# Apply immediately if we already have onready refs.
		if is_node_ready():
			_apply_npc_config()

var money: int = 0
var _npc_config: NpcConfig = null
var _route_id: RouteIds.Id = RouteIds.Id.NONE
var _waypoints: Array[Vector2] = []
var _waypoint_idx: int = 0
var _state: StringName = NPCStateNames.NONE

@onready var agent_component: AgentComponent = $Components/AgentComponent
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Avoid mutating shared `.tres` resources from `res://`.
	if inventory != null and String(inventory.resource_path).begins_with("res://"):
		inventory = inventory.duplicate(true)

	_apply_npc_config()

func _physics_process(_delta: float) -> void:
	match _state:
		NPCStateNames.FOLLOW_ROUTE:
			_step_follow_route()
		_:
			_step_idle()

func set_npc_config(cfg: NpcConfig) -> void:
	npc_config = cfg

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

	# Movement policy (will be replaced by a real state machine later)
	if GameManager != null:
		_route_id = cfg.get_route_id_for_level(GameManager.get_active_level_id())
	else:
		_route_id = RouteIds.Id.NONE
	if cfg.move_speed > 0.0:
		move_speed = cfg.move_speed
	_refresh_route()

func _refresh_route() -> void:
	_waypoints.clear()
	_waypoint_idx = 0
	if _route_id == RouteIds.Id.NONE:
		_state = NPCStateNames.IDLE
		return
	if GameManager == null:
		_state = NPCStateNames.IDLE
		return
	var lr := GameManager.get_active_level_root()
	if lr == null:
		_state = NPCStateNames.IDLE
		return
	_waypoints = lr.get_route_waypoints_global(_route_id)
	_waypoint_idx = _find_nearest_waypoint_index(global_position)
	_state = NPCStateNames.FOLLOW_ROUTE if not _waypoints.is_empty() else NPCStateNames.IDLE

func _find_nearest_waypoint_index(pos: Vector2) -> int:
	if _waypoints.is_empty():
		return 0
	var best_i := 0
	var best_d2 := INF
	for i in range(_waypoints.size()):
		var d2 := pos.distance_squared_to(_waypoints[i])
		if d2 < best_d2:
			best_d2 = d2
			best_i = i
	return best_i

func _step_idle() -> void:
	velocity = Vector2.ZERO
	_play_anim_for_motion(Vector2.ZERO)

func _step_follow_route() -> void:
	if _waypoints.is_empty():
		_state = NPCStateNames.IDLE
		_step_idle()
		return

	var target := _waypoints[_waypoint_idx]
	var to_target := target - global_position
	if to_target.length() <= _WAYPOINT_EPS:
		_waypoint_idx = (_waypoint_idx + 1) % _waypoints.size()
		target = _waypoints[_waypoint_idx]
		to_target = target - global_position

	var dir := to_target.normalized()
	velocity = dir * move_speed
	move_and_slide()
	_play_anim_for_motion(velocity)

func _play_anim_for_motion(v: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	var moving := v.length() > 0.1
	var desired := &""
	if moving:
		desired = _dir_anim_name(&"move", v)
	else:
		desired = _dir_anim_name(&"idle", v)

	if not String(desired).is_empty() and sprite.sprite_frames.has_animation(desired):
		if sprite.animation != desired:
			sprite.play(desired)

func _dir_anim_name(prefix: StringName, v: Vector2) -> StringName:
	# Supports either "idle_front/move_front" directional sets,
	# or a single "idle/move" animation if present.
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(prefix):
		return prefix
	if abs(v.x) > abs(v.y):
		if v.x >= 0.0:
			return StringName("%s_right" % String(prefix))
		return StringName("%s_left" % String(prefix))
	if v.y >= 0.0:
		return StringName("%s_front" % String(prefix))
	return StringName("%s_back" % String(prefix))

func apply_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	money = int(rec.money)

func capture_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	rec.money = int(money)
