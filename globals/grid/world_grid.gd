extends Node

## Facade over the grid subsystems.
## - `terrain_state`: persisted terrain deltas + render events + farm simulation
## - `occupancy`: runtime-only entity registration/queries
## - `tile_map`: tile map access
##
## Keep this thin so gameplay code doesn't need to know which subsystem to call.

var terrain_state: TerrainState
var occupancy: OccupancyGrid
var tile_map: TileMapManager

# Occupants may attempt to register before WorldGrid is bound to a level.
# Buffer those requests and flush after bind_level_root succeeds.
# instance_id -> WeakRef(GridOccupantComponent)
var _pending_occupant_regs: Dictionary[int, WeakRef] = {}

func _ready() -> void:
	# Instantiate subsystems
	tile_map = TileMapManager.new()
	tile_map.name = "TileMapManager"
	add_child(tile_map)

	occupancy = OccupancyGrid.new()
	occupancy.name = "OccupancyGrid"
	add_child(occupancy)

	terrain_state = TerrainState.new()
	terrain_state.name = "TerrainState"
	terrain_state.setup(tile_map, occupancy)
	add_child(terrain_state)

	set_process(false)

func ensure_initialized() -> bool:
	# Used by hydrators/capture code. WorldGrid is considered initialized only when
	# all subsystems are bound to the active level scene.
	if tile_map == null or occupancy == null or terrain_state == null:
		return false
	if not tile_map.ensure_initialized():
		return false
	if not occupancy.ensure_initialized():
		return false
	if not terrain_state.ensure_initialized():
		return false
	return true

func bind_level_root(level_root: LevelRoot) -> bool:
	# Deterministic init: bind the active level once after a scene change.
	if level_root == null or not is_instance_valid(level_root):
		return false
	if tile_map == null or occupancy == null or terrain_state == null:
		return false
	if not tile_map.bind_level_root(level_root):
		return false
	if not occupancy.bind_level_root(level_root):
		return false
	if not terrain_state.bind_level_root(level_root):
		return false
	_flush_pending_occupant_regs()
	return true

func unbind() -> void:
	# Called when leaving gameplay (e.g. back to main menu).
	_pending_occupant_regs.clear()
	if tile_map != null:
		tile_map.unbind()
	if occupancy != null:
		occupancy.unbind()
	if terrain_state != null:
		terrain_state.unbind()

func queue_occupant_registration(comp: Node) -> void:
	# Called by GridOccupantComponent when WorldGrid isn't bound yet.
	if comp == null or not is_instance_valid(comp):
		return
	_pending_occupant_regs[int(comp.get_instance_id())] = weakref(comp)

func dequeue_occupant_registration(comp: Node) -> void:
	if comp == null:
		return
	_pending_occupant_regs.erase(int(comp.get_instance_id()))

func _flush_pending_occupant_regs() -> void:
	if _pending_occupant_regs.is_empty():
		return
	# Copy values then clear to avoid re-entrancy issues if registration queues again.
	var pending: Array = _pending_occupant_regs.values()
	_pending_occupant_regs.clear()
	for w in pending:
		if not (w is WeakRef):
			continue
		var c: Variant = (w as WeakRef).get_ref()
		if c == null or not is_instance_valid(c):
			continue
		# Only register components still in the active scene tree.
		if c is Node and (c as Node).is_inside_tree():
			if c.has_method("register_from_current_position"):
				c.call("register_from_current_position")

func apply_day_started(day_index: int) -> void:
	if terrain_state != null:
		terrain_state.apply_day_started(day_index)

# region Terrain facade

func set_soil(cell: Vector2i) -> bool:
	return terrain_state != null and terrain_state.set_soil(cell)

func set_wet(cell: Vector2i) -> bool:
	return terrain_state != null and terrain_state.set_wet(cell)

func plant_seed(cell: Vector2i, plant_id: StringName) -> bool:
	return terrain_state != null and terrain_state.plant_seed(cell, plant_id)

func clear_cell(cell: Vector2i) -> bool:
	return terrain_state != null and terrain_state.clear_cell(cell)

# endregion

# region Occupancy facade

func register_entity(cell: Vector2i, entity: Node, type: Enums.EntityType) -> void:
	if occupancy != null:
		occupancy.register_entity(cell, entity, type)

func unregister_entity(cell: Vector2i, entity: Node, type: Enums.EntityType) -> void:
	if occupancy != null:
		occupancy.unregister_entity(cell, entity, type)

func query_interactables_at(cell: Vector2i):
	var q: CellInteractionQuery = CellInteractionQuery.new()
	if occupancy != null:
		q = occupancy.get_entities_at(cell)

	# Only append terrain if not blocked by an obstacle.
	if not bool(q.has_obstacle) and terrain_state != null:
		var soil := terrain_state.get_soil_interactable()
		if soil != null:
			q.entities.append(soil)
	return q

func try_interact(ctx: InteractionContext) -> bool:
	## Centralized interaction dispatcher for both TOOL and USE.
	## - Pulls targets from get_interactables_at(ctx.cell)
	## - Sorts components by priority
	## - Stops at obstacle targets
	if ctx == null:
		return false

	var q: Variant = query_interactables_at(ctx.cell)
	var targets: Array = q.entities
	if targets.is_empty():
		return false

	for target in targets:
		if not is_instance_valid(target):
			continue

		# Context is reused across targets; just update the current target.
		ctx.target = target

		var comps := ComponentFinder.find_components_in_group(
			target,
			Groups.INTERACTABLE_COMPONENTS
		)
		if comps.is_empty():
			continue

		comps.sort_custom(func(a: Node, b: Node) -> bool:
			var ap: int = 0
			var bp: int = 0
			if a != null and a.has_method("get_priority"):
				ap = int(a.get_priority())
			if b != null and b.has_method("get_priority"):
				bp = int(b.get_priority())
			return ap > bp
		)

		for c in comps:
			if c != null and c.has_method("try_interact") and c.try_interact(ctx):
				return true

	return false

func try_interact_target(ctx: InteractionContext, target: Node) -> bool:
	## Dispatch interaction to a specific target node (used by raycast-first USE).
	if ctx == null or not is_instance_valid(target):
		return false

	ctx.target = target
	var comps := ComponentFinder.find_components_in_group(
		target,
		Groups.INTERACTABLE_COMPONENTS
	)
	if comps.is_empty():
		return false

	comps.sort_custom(func(a: Node, b: Node) -> bool:
		var ap: int = 0
		var bp: int = 0
		if a != null and a.has_method("get_priority"):
			ap = int(a.get_priority())
		if b != null and b.has_method("get_priority"):
			bp = int(b.get_priority())
		return ap > bp
	)

	for c in comps:
		if c != null and c.has_method("try_interact") and c.try_interact(ctx):
			return true
	return false

# endregion

# region Debug helpers

func debug_get_grid_data() -> Dictionary:
	# Returns a merged view (Vector2i -> GridCellData) for debug overlays only.
	if not OS.is_debug_build():
		return {}
	var out: Dictionary = {}

	var terrain_cells = terrain_state.debug_get_terrain_cells() if terrain_state != null else {}
	var occ_cells: Dictionary = occupancy.debug_get_cells() if occupancy != null else {}

	var all_cells := {}
	for c in terrain_cells:
		all_cells[c] = true
	for c in occ_cells:
		all_cells[c] = true

	for cell in all_cells:
		var gd := GridCellData.new()
		gd.coords = cell
		gd.terrain_id = GridCellData.TerrainType.NONE
		if terrain_state != null:
			gd.terrain_id = terrain_state.get_terrain_at(cell)

		var tdata = terrain_cells.get(cell)
		if tdata != null:
			gd.terrain_persist = bool(tdata.get("terrain_persist"))

		var odata = occ_cells.get(cell)
		if odata != null:
			gd.entities = odata.get("entities")
			gd.obstacles = odata.get("obstacles")

		out[cell] = gd

	return out

# endregion
