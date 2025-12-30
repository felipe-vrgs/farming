class_name GridDynamicOccupantComponent
extends GridOccupantComponent

## Tracks a moving entity's grid cell and keeps GridState registration in sync.
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
	if TileMapManager == null or GridState == null:
		return

	var world_pos := _get_world_pos()
	var new_cell := TileMapManager.global_to_cell(world_pos)
	if not force and new_cell == _current_cell:
		return

	_current_cell = new_cell

	# Re-register.
	unregister_all()
	# If we have an explicit position source (like Player feet), register at that cell.
	# Otherwise fall back to the base helper (supports optional rectangle collision shapes).
	if position_source != null:
		register_at(_current_cell)
	else:
		register_from_current_position()

	moved_to_cell.emit(_current_cell, world_pos)
	if emit_occupant_moved_event and EventBus:
		EventBus.occupant_moved_to_cell.emit(get_parent(), _current_cell, world_pos)

func _get_world_pos() -> Vector2:
	var p := get_parent()
	if p == null:
		return Vector2.ZERO

	if position_source != null:
		return position_source.global_position

	if p is Node2D:
		return (p as Node2D).global_position
	return p.global_position


