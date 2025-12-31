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

	npc.velocity = Vector2.ZERO
	request_animation_for_motion(Vector2.ZERO)
	return NPCStateNames.NONE

