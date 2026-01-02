extends NpcState

## Idle state - stands still, waits for brain to issue a MOVE_TO order.

func enter() -> void:
	super.enter()
	if npc == null:
		return
	npc.velocity = Vector2.ZERO
	request_animation_for_motion(Vector2.ZERO)
	if npc.footsteps_component:
		npc.footsteps_component.clear_timer()

func process_physics(_delta: float) -> StringName:
	if npc == null:
		return NPCStateNames.NONE

	# Check if brain wants us to move
	var order := _get_order()
	if order != null and order.action == AgentOrder.Action.MOVE_TO:
		return NPCStateNames.MOVING

	npc.velocity = Vector2.ZERO
	if order != null:
		npc.facing_dir = order.facing_dir
	request_animation_for_motion(Vector2.ZERO)
	return NPCStateNames.NONE

func _get_order() -> AgentOrder:
	if AgentBrain == null or npc == null or npc.agent_component == null:
		return null
	return AgentBrain.get_order(npc.agent_component.agent_id)
