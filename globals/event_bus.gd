extends Node

## Centralized Event Bus

@warning_ignore("unused_signal")
signal day_started(day_index: int)

@warning_ignore("unused_signal")
signal terrain_changed(cells: Array[Vector2i], from_terrain: int, to_terrain: int)

@warning_ignore("unused_signal")
signal cell_watered(cell: Vector2i)

@warning_ignore("unused_signal")
signal entity_damaged(entity: Node, amount: float, world_pos: Vector2)

@warning_ignore("unused_signal")
signal entity_depleted(entity: Node, world_pos: Vector2)

@warning_ignore("unused_signal")
signal player_moved_to_cell(cell: Vector2i, player_pos: Vector2)