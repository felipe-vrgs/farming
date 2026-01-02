class_name GridDynamicOccupantComponent
extends GridOccupantComponent

## Tracks a moving entity's grid cell and keeps WorldGrid registration in sync.
## Intended for Player/NPCs (CharacterBody2D), but works for any Node2D.

signal moved_to_cell(cell: Vector2i, world_pos: Vector2)

## Initial value that will never match a real cell.
const _INVALID_CELL := Vector2i(-9999, -9999)

## Optional node to use as the position source (e.g. Player's Feet marker).
@export var position_source: Marker2D = null

## Emit a global occupant move event for VFX/UX systems.
@export var emit_occupant_moved_event: bool = true

var _current_cell: Vector2i = _INVALID_CELL

func _ready() -> void:
	# We manage registration ourselves; don't auto-register in the base _ready.
	auto_register_on_ready = false
	set_physics_process(true)
	_refresh_registration(true)

func _exit_tree() -> void:
	unregister_all()

func _physics_process(_delta: float) -> void:
	_refresh_registration(false)

func get_current_cell() -> Vector2i:
	return _current_cell

func _on_state_applied() -> void:
	# Save state may change position; ensure the grid registry is consistent.
	_refresh_registration(true)

func _refresh_registration(force: bool) -> void:
	if WorldGrid.tile_map == null or WorldGrid == null:
		return

	var grid_world_pos := _get_grid_world_pos()
	var new_cell := WorldGrid.tile_map.global_to_cell(grid_world_pos)
	if not force and new_cell == _current_cell:
		return

	_current_cell = new_cell

	# Re-register.
	unregister_all()
	register_from_current_position()

	var vfx_pos := _get_vfx_world_pos(grid_world_pos)
	moved_to_cell.emit(_current_cell, vfx_pos)
	if emit_occupant_moved_event and EventBus:
		EventBus.occupant_moved_to_cell.emit(get_parent(), _current_cell, vfx_pos)

func _get_grid_world_pos() -> Vector2:
	var p := get_parent()
	if p == null:
		return Vector2.ZERO

	# Prefer collision shape center for grid occupancy (matches actual hitbox).
	if collision_shape != null and is_instance_valid(collision_shape):
		return collision_shape.global_position

	if p is Node2D:
		return (p as Node2D).global_position
	return p.global_position

func _get_vfx_world_pos(fallback: Vector2) -> Vector2:
	# VFX can use an explicit marker (e.g. feet) to look nicer.
	if position_source != null and is_instance_valid(position_source):
		return position_source.global_position
	return fallback


