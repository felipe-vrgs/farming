extends Node

## Centralized Event Bus

@warning_ignore("unused_signal")
signal day_started(day_index: int)

@warning_ignore("unused_signal")
signal day_tick_completed(day_index: int)

@warning_ignore("unused_signal")
signal terrain_changed(cells: Array[Vector2i], from_terrain: int, to_terrain: int)

@warning_ignore("unused_signal")
signal cell_watered(cell: Vector2i)

@warning_ignore("unused_signal")
signal entity_damaged(entity: Node, amount: float, world_pos: Vector2)

@warning_ignore("unused_signal")
signal entity_depleted(entity: Node, world_pos: Vector2)

@warning_ignore("unused_signal")
signal occupant_moved_to_cell(entity: Node, cell: Vector2i, world_pos: Vector2)

@warning_ignore("unused_signal")
signal travel_requested(agent: Node, target_spawn_point: SpawnPointData)

@warning_ignore("unused_signal")
signal level_change_requested(target_level_id: Enums.Levels, fallback_spawn_point: SpawnPointData)

@warning_ignore("unused_signal")
signal active_level_changed(prev_level_id: Enums.Levels, next_level_id: Enums.Levels)

@warning_ignore("unused_signal")
signal player_tool_equipped(tool_data: ToolData)

@warning_ignore("unused_signal")
signal dialogue_start_requested(actor: Node, npc: Node, dialogue_id: StringName)

@warning_ignore("unused_signal")
signal cutscene_start_requested(cutscene_id: StringName, actor: Node)

# Quest-facing generic channel (emitted by QuestEventRouter).
@warning_ignore("unused_signal")
signal quest_event(event_id: StringName, payload: Dictionary)

# Domain gameplay events (usable beyond quests).
@warning_ignore("unused_signal")
signal plant_harvested(
	plant_id: StringName, harvest_item_id: StringName, count: int, cell: Vector2i
)

@warning_ignore("unused_signal")
signal item_picked_up(item_id: StringName, count: int)

@warning_ignore("unused_signal")
signal shop_transaction(mode: StringName, item_id: StringName, count: int, vendor_id: StringName)

@warning_ignore("unused_signal")
signal quest_started(quest_id: StringName)

@warning_ignore("unused_signal")
signal quest_step_completed(quest_id: StringName, step_index: int)

@warning_ignore("unused_signal")
signal quest_completed(quest_id: StringName)

@warning_ignore("unused_signal")
signal relationship_changed(npc_id: StringName, units: int)
