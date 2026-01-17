class_name ShopOnInteract
extends InteractableComponent

## Interaction behavior for opening a shop on USE.
## Intended to live on NPC scenes and only activate for NPCs configured as shopkeepers.

@export var vendor_id_override: StringName = &""


func try_interact(ctx: InteractionContext) -> bool:
	if ctx == null or not ctx.is_use():
		return false

	var entity := get_entity()
	if entity == null or not "npc_config" in entity:
		return false

	# Only open shop if this entity is configured as a shopkeeper.
	if "npc_config" in entity:
		var cfg: Variant = entity.npc_config
		if cfg == null or not bool(cfg.get("is_shopkeeper")):
			return false

	var vendor_id := vendor_id_override
	if String(vendor_id).is_empty():
		# Prefer agent_id from AgentComponent.
		var ac := ComponentFinder.find_component_in_group(entity, Groups.AGENT_COMPONENTS)
		if ac is AgentComponent:
			vendor_id = (ac as AgentComponent).agent_id

	if String(vendor_id).is_empty():
		return false

	if Runtime != null and Runtime.has_method("open_shop"):
		Runtime.open_shop(vendor_id)
		return true

	return false


func get_prompt_text(ctx: InteractionContext) -> String:
	if ctx == null or not ctx.is_use():
		return ""
	var entity := get_entity()
	if entity == null or not ("npc_config" in entity):
		return ""
	var cfg: Variant = entity.npc_config
	if cfg == null or not bool(cfg.get("is_shopkeeper")):
		return ""
	return "Shop"
