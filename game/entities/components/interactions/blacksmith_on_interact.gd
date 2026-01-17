class_name BlacksmithOnInteract
extends InteractableComponent

## Interaction behavior for opening the Blacksmith UI on USE.
## Can be attached to an NPC or any interactable scene.

@export var vendor_id_override: StringName = &""


func try_interact(ctx: InteractionContext) -> bool:
	if ctx == null or not ctx.is_use():
		return false

	var entity := get_entity()
	if entity == null:
		return false

	# Only open blacksmith if this entity is configured as a blacksmith.
	if not ("npc_config" in entity):
		return false
	var cfg: Variant = entity.npc_config
	if cfg == null or not bool(cfg.get("is_blacksmith")):
		return false

	var vendor_id := vendor_id_override
	if String(vendor_id).is_empty():
		# Prefer agent_id from AgentComponent if present.
		var ac := ComponentFinder.find_component_in_group(entity, Groups.AGENT_COMPONENTS)
		if ac is AgentComponent:
			vendor_id = (ac as AgentComponent).agent_id

	if Runtime != null and Runtime.has_method("open_blacksmith"):
		Runtime.open_blacksmith(vendor_id)
		return true

	return false


func get_prompt_text(ctx: InteractionContext) -> String:
	if ctx == null or not ctx.is_use():
		return ""
	var entity := get_entity()
	if entity == null or not ("npc_config" in entity):
		return ""
	var cfg: Variant = entity.npc_config
	if cfg == null or not bool(cfg.get("is_blacksmith")):
		return ""
	return "Blacksmith"
