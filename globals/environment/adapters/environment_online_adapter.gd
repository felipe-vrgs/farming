class_name OnlineEnvironmentAdapter
extends EnvironmentSimulator.WorldAdapter

## Adapter that exposes the ACTIVE runtime world state (TerrainState + OccupancyGrid)
## as an EnvironmentSimulator.WorldAdapter.

var _terrain_state: Node

func _init(terrain_state: Node) -> void:
	_terrain_state = terrain_state

func get_cells_to_simulate() -> Array[Vector2i]:
	var cell_set := {}

	# Terrain deltas we currently know about (includes wet soil).
	if _terrain_state != null and _terrain_state.has_method("list_terrain_cells_for_simulation"):
		for c in _terrain_state.list_terrain_cells_for_simulation():
			cell_set[c] = true

	# Runtime plant positions.
	if WorldGrid.occupancy != null:
		for c in WorldGrid.occupancy.get_cells_with_entity_type(Enums.EntityType.PLANT):
			cell_set[c] = true

	var out: Array[Vector2i] = []
	for k in cell_set:
		out.append(k)
	return out

func get_terrain_at(cell: Vector2i) -> int:
	if _terrain_state != null and _terrain_state.has_method("get_terrain_at"):
		return int(_terrain_state.get_terrain_at(cell))
	return int(GridCellData.TerrainType.NONE)

func get_plant_data(cell: Vector2i) -> Variant:
	if WorldGrid.occupancy == null:
		return null
	var p = WorldGrid.occupancy.get_entity_of_type(cell, Enums.EntityType.PLANT)
	if p is Plant and p.data != null:
		return {"days_grown": p.days_grown, "days_to_grow": p.data.days_to_grow}
	return null
