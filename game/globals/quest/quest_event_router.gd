extends Node

## QuestEventRouter
## - Subscribes to domain gameplay events (EventBus, DialogueManager)
## - Emits a single quest-facing stream: EventBus.quest_event(event_id, payload)

var _npc_id_by_timeline_id: Dictionary = {}  # StringName timeline_id -> StringName npc_id


func _ready() -> void:
	# Must run while SceneTree is paused (menus/dialogue).
	process_mode = Node.PROCESS_MODE_ALWAYS

	if EventBus != null:
		if not EventBus.item_picked_up.is_connected(_on_item_picked_up):
			EventBus.item_picked_up.connect(_on_item_picked_up)
		if not EventBus.shop_transaction.is_connected(_on_shop_transaction):
			EventBus.shop_transaction.connect(_on_shop_transaction)
		if not EventBus.plant_harvested.is_connected(_on_plant_harvested):
			EventBus.plant_harvested.connect(_on_plant_harvested)
		if not EventBus.entity_depleted.is_connected(_on_entity_depleted):
			EventBus.entity_depleted.connect(_on_entity_depleted)
		if not EventBus.dialogue_start_requested.is_connected(_on_dialogue_start_requested):
			EventBus.dialogue_start_requested.connect(_on_dialogue_start_requested)

	if DialogueManager != null:
		if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
			DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _emit_quest_event(event_id: StringName, payload: Dictionary) -> void:
	if EventBus == null:
		return
	if String(event_id).is_empty():
		return
	EventBus.quest_event.emit(event_id, payload if payload != null else {})


func _on_item_picked_up(item_id: StringName, count: int) -> void:
	if String(item_id).is_empty() or count <= 0:
		return
	_emit_quest_event(&"items_gained", {"item_id": item_id, "count": int(count)})


func _on_shop_transaction(
	mode: StringName, item_id: StringName, count: int, vendor_id: StringName
) -> void:
	if String(item_id).is_empty() or count <= 0:
		return
	var ev := &""
	if mode == &"sell":
		ev = &"items_sold"
	elif mode == &"buy":
		ev = &"items_bought"
	else:
		ev = &"shop_transaction"
	_emit_quest_event(
		ev,
		{
			"mode": mode,
			"item_id": item_id,
			"count": int(count),
			"vendor_id": vendor_id,
		}
	)


func _on_plant_harvested(
	plant_id: StringName, harvest_item_id: StringName, count: int, cell: Vector2i
) -> void:
	_emit_quest_event(
		&"plant_harvested",
		{
			"plant_id": plant_id,
			"harvest_item_id": harvest_item_id,
			"count": int(count),
			"cell": cell,
		}
	)


func _on_entity_depleted(entity: Node, world_pos: Vector2) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var kind := _infer_entity_kind(entity)
	_emit_quest_event(
		&"entity_depleted",
		{
			"kind": kind,
			"world_pos": world_pos,
		}
	)


func _on_dialogue_start_requested(_actor: Node, npc: Node, dialogue_id: StringName) -> void:
	# Mirror DialogueManager's timeline_id scheme: "npcs/{npc_id}/{dialogue_id}"
	var npc_id := _get_npc_id(npc)
	if String(npc_id).is_empty() or String(dialogue_id).is_empty():
		return
	var timeline_id := StringName("npcs/" + String(npc_id) + "/" + String(dialogue_id))
	_npc_id_by_timeline_id[timeline_id] = npc_id


func _on_dialogue_ended(timeline_id: StringName) -> void:
	# Convert completed dialogue timelines into a "talked_to_npc" quest event.
	if String(timeline_id).is_empty() or not String(timeline_id).begins_with("npcs/"):
		return
	var npc_id: StringName = _npc_id_by_timeline_id.get(timeline_id, &"")
	_npc_id_by_timeline_id.erase(timeline_id)
	if String(npc_id).is_empty():
		return
	_emit_quest_event(&"talked_to_npc", {"npc_id": npc_id, "timeline_id": timeline_id})


func _get_npc_id(npc: Node) -> StringName:
	if npc == null or not is_instance_valid(npc):
		return &""

	# Prefer AgentComponent id (stable identity).
	var ac: Node = npc.get_node_or_null(NodePath("Components/AgentComponent"))
	if ac == null:
		ac = npc.get_node_or_null(NodePath("AgentComponent"))
	if ac != null and "agent_id" in ac:
		return ac.agent_id

	# Fallback: NpcConfig identity.
	if "npc_config" in npc and npc.npc_config != null and "npc_id" in npc.npc_config:
		return npc.npc_config.npc_id

	# Last resort: node name (not stable across scene edits; avoid relying on this for real quests).
	return StringName(String(npc.name).to_snake_case())


func _infer_entity_kind(entity: Node) -> StringName:
	# Best-effort: use script class_name if available, otherwise built-in class.
	if entity == null:
		return &""
	var script: Variant = entity.get_script()
	if script is Script:
		var gn := (script as Script).get_global_name()
		if not gn.is_empty():
			return StringName(gn.to_snake_case())
	return StringName(String(entity.get_class()).to_snake_case())
