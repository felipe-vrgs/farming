class_name TreeEntity
extends StaticBody2D

## Texture to use for the tree.
@export var texture: Texture2D
## Damage taken per axe hit.
@export var hit_damage: float = 25.0


var _occupied_cells: Array[Vector2i] = []

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Ensure we have a sprite and texture setup
	if texture:
		sprite.texture = texture

	# Determine our base grid position for snapping
	var base_grid_pos = TileMapManager.global_to_cell(global_position)
	# Snap to the center of the tile for consistency
	global_position = TileMapManager.cell_to_global(base_grid_pos)

	# Register all cells covered by our hitbox
	_register_occupied_cells()

	# Connect signals
	health_component.depleted.connect(_on_depleted)

func _register_occupied_cells() -> void:
	if collision_shape == null or collision_shape.shape == null:
		# Fallback to single cell if no shape is found
		var cell = TileMapManager.global_to_cell(global_position)
		SoilGridState.register_obstacle(cell, self)
		_occupied_cells.append(cell)
		return

	# Calculate the bounding box of the collision shape in world space
	var shape_rect: Rect2
	if collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		shape_rect = Rect2(collision_shape.global_position - rect_shape.size * 0.5, rect_shape.size)
	else:
		# For other shapes (circles, etc), use a simple approximation or just the center
		var cell = TileMapManager.global_to_cell(global_position)
		SoilGridState.register_obstacle(cell, self)
		_occupied_cells.append(cell)
		return

	# Find the range of cells covered by this rect
	var start_cell = TileMapManager.global_to_cell(shape_rect.position)
	var end_cell = TileMapManager.global_to_cell(shape_rect.end)

	for x in range(start_cell.x, end_cell.x + 1):
		for y in range(start_cell.y, end_cell.y + 1):
			var cell = Vector2i(x, y)
			SoilGridState.register_obstacle(cell, self)
			_occupied_cells.append(cell)

func _on_depleted() -> void:
	# Unregister all cells we occupied
	for cell in _occupied_cells:
		SoilGridState.unregister_obstacle(cell)

	# Future: Spawn wood loot, play destruction VFX/SFX
	queue_free()

## Called by tools to damage the tree.
func hit(_damage_override: float = -1.0) -> void:
	var damage = _damage_override if _damage_override > 0 else hit_damage
	health_component.take_damage(damage)

