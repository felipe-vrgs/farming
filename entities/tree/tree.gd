class_name TreeEntity
extends GridEntity

## Texture to use for the tree.
@export var texture: Texture2D
## Damage taken per axe hit.
@export var hit_damage: float = 25.0

var _occupied_cells: Array[Vector2i] = []

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D
# Collision is now a child node or part of the structure
@onready var collision_body: StaticBody2D = $StaticBody2D
@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

func _init() -> void:
	entity_type = EntityType.TREE

func _ready() -> void:
	# Ensure we have a sprite and texture setup
	if texture:
		sprite.texture = texture

	# Connect signals
	health_component.depleted.connect(_on_depleted)

	# Base class calls _snap_to_grid and _register_on_grid
	super._ready()

func _register_on_grid() -> void:
	# Override to register multiple cells based on collision shape
	if collision_shape == null or collision_shape.shape == null:
		# Fallback to single cell (handled by base, but we use _occupied_cells tracking)
		super._register_on_grid()
		_occupied_cells.append(grid_pos)
		return

	# Calculate the bounding box of the collision shape in world space
	var shape_rect: Rect2
	if collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		# Note: collision_shape.global_position might be relative to body
		shape_rect = Rect2(collision_shape.global_position - rect_shape.size * 0.5, rect_shape.size)
	else:
		super._register_on_grid()
		_occupied_cells.append(grid_pos)
		return

	# Find the range of cells covered by this rect
	var start_cell = TileMapManager.global_to_cell(shape_rect.position)
	var end_cell = TileMapManager.global_to_cell(shape_rect.end)

	for x in range(start_cell.x, end_cell.x + 1):
		for y in range(start_cell.y, end_cell.y + 1):
			var cell = Vector2i(x, y)
			GridState.register_entity(cell, self)
			_occupied_cells.append(cell)

func _exit_tree() -> void:
	# Override to unregister all cells
	for cell in _occupied_cells:
		GridState.unregister_entity(cell, self)

func _on_depleted() -> void:
	# _exit_tree handles unregistration automatically when queue_free is called
	# Future: Spawn wood loot, play destruction VFX/SFX
	queue_free()

func on_interact(tool_data: ToolData) -> void:
	# Validate tool target type
	if tool_data.target_type == EntityType.TREE:
		health_component.take_damage(hit_damage)
