class_name Player
extends CharacterBody2D

@export var player_balance_config: PlayerBalanceConfig
@export var player_input_config: PlayerInputConfig

## How far in front of the player we consider "interactable" (in pixels).
@export var interact_distance: float = 8.0

var _facing_dir: Vector2 = Vector2.DOWN
var _interact_tile_layers: Array[TileMapLayer] = []

@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_ray: RayCast2D = $InteractRay
@onready var soil_interactivity_manager: SoilInteractivityManager = $SoilInteractivityManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize Input Map
	player_input_config.ensure_actions_registered()

	# Connect to state machine binding request
	state_machine.state_binding_requested.connect(_on_state_binding_requested)

	# Initialize State Machine
	state_machine.init()
	_interact_tile_layers = _resolve_interact_tile_layers()

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)
	_update_interact_ray()
	move_and_slide()

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)
	if event.is_action_pressed(player_input_config.action_interact):
		_interact()

func _update_interact_ray() -> void:
	if velocity.length() > 0.1:
		_facing_dir = velocity.normalized()
	interact_ray.target_position = _facing_dir * interact_distance

func _interact() -> void:
	var tile_info = _get_tile_info_in_front()
	if tile_info != null:
		var cell = tile_info.get("cell", Vector2i.ZERO)
		soil_interactivity_manager.interact_at_cell(cell)

func _on_state_binding_requested(state: State) -> void:
	state.bind_player(self)
	state.animation_change_requested.connect(_on_animation_change_requested)

func _on_animation_change_requested(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

func set_terrain_collision(enabled: bool) -> void:
	const TERRAIN_BIT := 1 << 1  # Layer 2
	const GUARDRAILS_BIT := 1 << 2  # Layer 3
	if enabled:
		z_index = 15
		collision_mask = TERRAIN_BIT | GUARDRAILS_BIT  # 6
	else:
		z_index = 35  # Above Decor (30), below future overlays
		collision_mask = GUARDRAILS_BIT  # 4

func _resolve_interact_tile_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	var scene := get_tree().current_scene
	if scene == null:
		return layers

	# For now, we only interact with the Ground layer.
	var ground_map := scene.get_node_or_null(NodePath("GroundMaps/Ground"))
	if ground_map == null:
		return layers
	if not (ground_map is TileMapLayer):
		return layers

	return [ground_map as TileMapLayer]

func _get_tile_info_in_front() -> Variant:
	if _interact_tile_layers.is_empty():
		_interact_tile_layers = _resolve_interact_tile_layers()
		if _interact_tile_layers.is_empty():
			return null

	var front_global := global_position + (_facing_dir.normalized() * interact_distance)

	for layer in _interact_tile_layers:
		if layer == null:
			continue

		var cell := layer.local_to_map(layer.to_local(front_global))
		var source_id := layer.get_cell_source_id(cell)
		if source_id == -1:
			continue

		var atlas_coords := layer.get_cell_atlas_coords(cell)
		var alternative := layer.get_cell_alternative_tile(cell)
		var tile_data := layer.get_cell_tile_data(cell)

		var info := {
			"layer": layer.name,
			"cell": cell,
			"source_id": source_id,
			"atlas_coords": atlas_coords,
			"alternative": alternative,
		}

		if tile_data != null:
			# Helpful for terrain-based interactions (farming, water, etc)
			info["terrain_set"] = tile_data.get("terrain_set")
			info["terrain"] = tile_data.get("terrain")
			info["custom_data"] = _get_custom_data_dump(layer, tile_data)

		return info

	return null

func _get_custom_data_dump(layer: TileMapLayer, tile_data: TileData) -> Dictionary:
	var result: Dictionary = {}
	var ts := layer.tile_set
	if ts == null:
		return result

	var count := ts.get_custom_data_layers_count()
	for i in range(count):
		var key: StringName = ts.get_custom_data_layer_name(i)
		result[key] = tile_data.get_custom_data(key)
	return result
