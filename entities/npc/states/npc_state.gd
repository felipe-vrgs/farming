class_name NpcState
extends State

## NpcState - base class for NPC states.
const _MOVE_EPS := 0.1
const _WAYPOINT_EPS := 2.0

var npc: NPC
var npc_config: NpcConfig

func bind_parent(new_parent: Node) -> void:
	super.bind_parent(new_parent)
	if new_parent is NPC:
		npc = new_parent
		npc_config = npc.npc_config

func enter() -> void:
	super.enter()
	if npc:
		npc_config = npc.npc_config


func would_collide(motion: Vector2) -> bool:
	if npc == null:
		return false
	if npc.route_blocked_by_player:
		return true
	return npc.test_move(npc.global_transform, motion)

## Check collision ignoring the player blocker area (for sidestep probing/movement).
func would_collide_physics_only(motion: Vector2) -> bool:
	if npc == null:
		return false
	return npc.test_move(npc.global_transform, motion)

func request_animation_for_motion(v: Vector2) -> void:
	if npc == null:
		return

	if v.length() > _MOVE_EPS:
		npc.facing_dir = v

	var moving := v.length() > _MOVE_EPS
	var prefix := &"move" if moving else &"idle"

	var dir: Vector2 = npc.facing_dir
	if dir.length() <= _MOVE_EPS:
		dir = Vector2.DOWN

	var anim := _dir_anim_name(prefix, dir)
	if not String(anim).is_empty():
		animation_change_requested.emit(anim)

func _dir_anim_name(prefix: StringName, dir: Vector2) -> StringName:
	if npc != null and npc.sprite != null and npc.sprite.sprite_frames != null:
		if npc.sprite.sprite_frames.has_animation(prefix):
			return prefix

	if abs(dir.x) > abs(dir.y):
		if dir.x >= 0.0:
			return StringName("%s_right" % String(prefix))
		return StringName("%s_left" % String(prefix))
	if dir.y >= 0.0:
		return StringName("%s_front" % String(prefix))
	return StringName("%s_back" % String(prefix))

func _get_order() -> AgentOrder:
	if AgentBrain == null or npc == null or npc.agent_component == null:
		return null
	return AgentBrain.get_order(npc.agent_component.agent_id)

func _report_reached() -> void:
	if AgentBrain == null or npc == null or npc.agent_component == null:
		return
	var status := AgentStatus.new()
	status.agent_id = npc.agent_component.agent_id
	status.position = npc.global_position
	status.reached_target = true
	AgentBrain.report_status(status)

func _report_moving() -> void:
	if AgentBrain == null or npc == null or npc.agent_component == null:
		return
	var status := AgentStatus.new()
	status.agent_id = npc.agent_component.agent_id
	status.position = npc.global_position
	status.reached_target = false
	AgentBrain.report_status(status)

func _report_blocked(reason: AgentOrder.BlockReason, blocked_duration: float) -> void:
	if AgentBrain == null or npc == null or npc.agent_component == null:
		return
	var status := AgentStatus.new()
	status.agent_id = npc.agent_component.agent_id
	status.position = npc.global_position
	status.reached_target = false
	status.is_blocked = true
	status.block_reason = reason
	status.blocked_duration = blocked_duration
	AgentBrain.report_status(status)

func _detect_block_reason() -> AgentOrder.BlockReason:
	if npc == null:
		return AgentOrder.BlockReason.OBSTACLE
	if npc.route_blocked_by_player:
		return AgentOrder.BlockReason.PLAYER
	return AgentOrder.BlockReason.OBSTACLE

func _reset_motion() -> void:
	if npc == null:
		return
	npc.velocity = Vector2.ZERO
	request_animation_for_motion(Vector2.ZERO)
	if npc.footsteps_component:
		npc.footsteps_component.clear_timer()