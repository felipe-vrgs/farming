extends Node2D

## Damage taken per axe hit.
@export var hit_damage: float = 25.0
@export var hit_sound: AudioStream = preload("res://assets/sounds/tools/chop.ogg")

var _pending_saved_health: float = -1.0

@onready var health_component: HealthComponent = $HealthComponent
# Collision is now a child node or part of the structure
@onready var collision_body: StaticBody2D = $StaticBody2D
@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var grid_occupant: GridOccupantComponent = $GridOccupantComponent

func _ready() -> void:
	_register_on_grid()
	# Apply loaded state after onready vars are available.
	if _pending_saved_health >= 0.0:
		health_component.current_health = clampf(_pending_saved_health, 0.0, health_component.max_health)
		health_component.health_changed.emit(health_component.current_health, health_component.max_health)

func _register_on_grid() -> void:
	var cell = TileMapManager.global_to_cell(global_position)
	# Override to register multiple cells based on collision shape
	if collision_shape == null or collision_shape.shape == null:
		# Fallback to single cell (handled by base, but we use _occupied_cells tracking)
		if grid_occupant:
			grid_occupant.register_at(cell)
		return

	# Calculate the bounding box of the collision shape in world space
	var shape_rect: Rect2
	if collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		# Note: collision_shape.global_position might be relative to body
		shape_rect = Rect2(collision_shape.global_position - rect_shape.size * 0.5, rect_shape.size)
	else:
		if grid_occupant:
			grid_occupant.register_at(cell)
		return

	# Find the range of cells covered by this rect
	var start_cell = TileMapManager.global_to_cell(shape_rect.position)
	var end_cell = TileMapManager.global_to_cell(shape_rect.end)

	for x in range(start_cell.x, end_cell.x + 1):
		for y in range(start_cell.y, end_cell.y + 1):
			var cell_to_register = Vector2i(x, y)
			if grid_occupant:
				grid_occupant.register_at(cell_to_register)

func on_interact(tool_data: ToolData, _cell: Vector2i = Vector2i.ZERO) -> bool:
	if tool_data.action_kind == Enums.ToolActionKind.AXE:
		health_component.take_damage(hit_damage)
		if hit_sound:
			SFXManager.play(hit_sound, global_position)
		return true

	return false

func get_save_state() -> Dictionary:
	return {
		"current_health": health_component.current_health if health_component != null else -1.0,
	}

func apply_save_state(state: Dictionary) -> void:
	_pending_saved_health = float(state.get("current_health", -1.0))
