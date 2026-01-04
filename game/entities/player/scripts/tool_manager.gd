class_name ToolManager
extends Node

## Minimum time (in seconds) between tool uses.
@export var tool_cooldown: float = 0.2

var player: Player
var tool_shovel: ToolData = preload("res://game/entities/tools/data/shovel.tres")
var tool_water: ToolData = preload("res://game/entities/tools/data/watering_can.tres")
var tool_seeds: ToolData = preload("res://game/entities/tools/data/seeds.tres")
var tool_axe: ToolData = preload("res://game/entities/tools/data/axe.tres")
var tool_hand: ToolData = preload("res://game/entities/tools/data/hand.tres")

var available_seeds: Dictionary[StringName, PlantData] = {
	"tomato": preload("res://game/entities/plants/types/tomato.tres"),
}

var tools: Array[ToolData] = []
var _tool_by_id: Dictionary[StringName, ToolData] = {}

var _selected_tool_id: StringName = &""

var _tool_cooldown_timer: float = 0.0
var _current_seed: StringName = "tomato"


func _ready() -> void:
	player = owner as Player
	# Ensure per-player instances (avoid mutating shared `.tres` resources).
	tool_shovel = tool_shovel.duplicate(true)
	tool_water = tool_water.duplicate(true)
	tool_seeds = tool_seeds.duplicate(true)
	tool_axe = tool_axe.duplicate(true)
	tool_hand = tool_hand.duplicate(true)

	tools = [tool_shovel, tool_seeds, tool_water, tool_axe, tool_hand]
	_tool_by_id.clear()
	for t in tools:
		if t == null:
			continue
		_tool_by_id[t.id] = t

	# Defer to ensure player.tool_node is ready
	call_deferred("_initial_equip")


func _initial_equip() -> void:
	if player.tool_node and player.tool_node.data:
		EventBus.player_tool_equipped.emit(player.tool_node.data)
		return

	equip_tool(tool_shovel)


func _process(delta: float) -> void:
	if _tool_cooldown_timer > 0:
		_tool_cooldown_timer -= delta


func equip_tool(data: ToolData) -> void:
	if not player or not player.tool_node:
		return
	_selected_tool_id = data.id if data != null else &""
	player.tool_node.data = data
	EventBus.player_tool_equipped.emit(data)


func start_tool_cooldown(duration: float = -1.0) -> void:
	if duration < 0:
		_tool_cooldown_timer = tool_cooldown
	else:
		_tool_cooldown_timer = duration


func can_use_tool() -> bool:
	return _tool_cooldown_timer <= 0.0


func select_tool(index: int) -> void:
	if index < 0 or index >= tools.size():
		return

	var item = tools[index]

	if item == tool_seeds:
		_selected_tool_id = tool_seeds.id
		_cycle_seeds()
		return

	if item is ToolData:
		equip_tool(item)


func get_selected_tool_id() -> StringName:
	if _selected_tool_id != &"":
		return _selected_tool_id
	if player and player.tool_node and player.tool_node.data:
		return (player.tool_node.data as ToolData).id
	return &""


func get_selected_seed_id() -> StringName:
	return _current_seed


func apply_selection(tool_id: StringName, seed_id: StringName) -> void:
	if seed_id != &"":
		_current_seed = seed_id

	if tool_id == &"":
		return

	# Seeds need extra-data applied before equip so the tool can use it immediately.
	if tool_id == tool_seeds.id:
		_selected_tool_id = tool_seeds.id
		_apply_seed_selection()
		return

	if _tool_by_id.has(tool_id):
		var data := _tool_by_id[tool_id] as ToolData
		if data != null:
			equip_tool(data)


func _cycle_seeds() -> void:
	if available_seeds.is_empty():
		return
	var keys = available_seeds.keys()
	if player.tool_node.data != tool_seeds:
		# Just equip the first/current one
		_apply_seed_selection()
	else:
		# Cycle to next key
		var idx = keys.find(_current_seed)
		_current_seed = keys[(idx + 1) % keys.size()]
		_apply_seed_selection()


func _apply_seed_selection() -> void:
	var plant_res = available_seeds[_current_seed]
	var plant = plant_res as PlantData

	if not plant:
		push_error("Selected seed is not a valid PlantData resource: %s" % plant_res)
		return

	tool_seeds.extra_data["plant_id"] = plant.resource_path
	tool_seeds.display_name = plant.plant_name + " Seeds"

	equip_tool(tool_seeds)
