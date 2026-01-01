class_name TalkOnInteract
extends InteractableComponent

## Minimal talk interaction hook (Dialogic integration comes later).
## Triggered on InteractionContext.Kind.USE.

@export var dialogue_id: StringName = &""

func try_interact(ctx: InteractionContext) -> bool:
	if ctx == null or not ctx.is_use():
		return false

	var npc := get_parent()
	if npc == null:
		return false

	# Placeholder behavior for now.
	if EventBus:
		EventBus.talk_requested.emit(ctx.actor, npc, dialogue_id)
	else:
		print("Talk requested:", npc.name, " dialogue_id=", String(dialogue_id))

	return true

