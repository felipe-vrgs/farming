extends NpcState

func enter() -> void:
	super.enter()
	if npc == null:
		return
	npc.velocity = Vector2.ZERO
	request_animation_for_motion(Vector2.ZERO)

func process_physics(_delta: float) -> StringName:
	if npc == null:
		return NPCStateNames.NONE

	# If this NPC has a configured route for the active level, switch into FOLLOW_ROUTE.
	if get_active_route_id() != RouteIds.Id.NONE:
		return NPCStateNames.ROUTE_IN_PROGRESS

	npc.velocity = Vector2.ZERO
	request_animation_for_motion(Vector2.ZERO)
	return NPCStateNames.NONE

