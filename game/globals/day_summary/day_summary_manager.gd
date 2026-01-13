extends Node

## Tracks per-day deltas and presents the end-of-day summary screen.
##
## Design goals:
## - Lightweight counters driven by EventBus signals.
## - No-op in headless/tests (FARMING_TEST_MODE) so CI stays deterministic.
## - Presentation is awaited and safe to call from SleepService's `on_black` hook.

const _END_OF_DAY_SCREEN_SCENE: PackedScene = preload(
	"res://game/ui/end_of_day/end_of_day_screen.tscn"
)

var _day_index: int = 1
var _money_start: int = 0

# Per-day counters.
var _items_gained: Dictionary = {}  # StringName -> int
var _seeds_planted: Dictionary = {}  # StringName -> int (plant_id)
var _watered_cells: Dictionary = {}  # Vector2i -> bool (set semantics)
var _harvests_by_plant: Dictionary = {}  # StringName -> int (plant_id -> harvest events)

# Per-day shop activity (kept separate from "gained" items).
var _shop_buys: Dictionary = {}  # StringName -> int
var _shop_sells: Dictionary = {}  # StringName -> int

# Quest highlights for the day (optional; used for emphasis only).
var _quest_steps_completed: Array[Dictionary] = []  # {quest_id, step_index}
var _quests_completed: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Headless mode: avoid connecting to global signals to keep tests isolated.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		return

	if TimeManager != null and "current_day" in TimeManager:
		_day_index = int(TimeManager.current_day)

	# Best-effort bootstrap if we started mid-day (e.g. loaded a save).
	call_deferred("_bootstrap_from_current_state")

	if EventBus == null:
		return

	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)

	if (
		EventBus.has_signal("item_picked_up")
		and not EventBus.item_picked_up.is_connected(_on_item_picked_up)
	):
		EventBus.item_picked_up.connect(_on_item_picked_up)

	if (
		EventBus.has_signal("plant_harvested")
		and not EventBus.plant_harvested.is_connected(_on_plant_harvested)
	):
		EventBus.plant_harvested.connect(_on_plant_harvested)

	if (
		EventBus.has_signal("cell_watered")
		and not EventBus.cell_watered.is_connected(_on_cell_watered)
	):
		EventBus.cell_watered.connect(_on_cell_watered)

	if (
		EventBus.has_signal("shop_transaction")
		and not EventBus.shop_transaction.is_connected(_on_shop_transaction)
	):
		EventBus.shop_transaction.connect(_on_shop_transaction)

	if (
		EventBus.has_signal("quest_step_completed")
		and not EventBus.quest_step_completed.is_connected(_on_quest_step_completed)
	):
		EventBus.quest_step_completed.connect(_on_quest_step_completed)

	if (
		EventBus.has_signal("quest_completed")
		and not EventBus.quest_completed.is_connected(_on_quest_completed)
	):
		EventBus.quest_completed.connect(_on_quest_completed)

	if (
		EventBus.has_signal("seed_planted")
		and not EventBus.seed_planted.is_connected(_on_seed_planted)
	):
		EventBus.seed_planted.connect(_on_seed_planted)


func _bootstrap_from_current_state() -> void:
	_reset_counters()
	# Best-effort: wait for the player to exist so money baseline is correct on boot/load.
	if get_tree() != null:
		await get_tree().process_frame
	_money_start = _get_player_money()


func reset_for_new_day(day_index: int) -> void:
	_day_index = int(day_index)
	_reset_counters()
	_money_start = _get_player_money()


func present_end_of_day_screen(reason: StringName = &"") -> void:
	# Headless/tests: no UI, no timing side effects.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		return
	if _END_OF_DAY_SCREEN_SCENE == null:
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return

	var money_end := _get_player_money()
	var model := {
		"day_index": int(_day_index),
		"reason": String(reason),
		"money_start": int(_money_start),
		"money_end": int(money_end),
		"money_delta": int(money_end - _money_start),
		"items_gained": _items_gained.duplicate(true),
		"seeds_planted": _seeds_planted.duplicate(true),
		"cells_watered": int(_watered_cells.size()),
		"harvests_by_plant": _harvests_by_plant.duplicate(true),
		"shop_buys": _shop_buys.duplicate(true),
		"shop_sells": _shop_sells.duplicate(true),
		"quest_steps_completed": _quest_steps_completed.duplicate(true),
		"quests_completed": _quests_completed.duplicate(true),
	}

	var inst := _END_OF_DAY_SCREEN_SCENE.instantiate()
	if inst == null:
		return
	tree.root.add_child(inst)

	if inst.has_method("setup"):
		inst.call("setup", model)

	# Await the screen's close signal if present; otherwise return immediately.
	if inst.has_signal("closed"):
		await inst.closed

	if is_instance_valid(inst):
		inst.queue_free()


func _reset_counters() -> void:
	_items_gained.clear()
	_seeds_planted.clear()
	_watered_cells.clear()
	_harvests_by_plant.clear()
	_shop_buys.clear()
	_shop_sells.clear()
	_quest_steps_completed.clear()
	_quests_completed.clear()


func _on_day_started(day_index: int) -> void:
	# 06:00 tick indicates the new day is now active; start tracking from here.
	reset_for_new_day(day_index)


func _on_item_picked_up(item_id: StringName, count: int) -> void:
	_inc_dict(_items_gained, item_id, count)


func _on_seed_planted(plant_id: StringName, _cell: Vector2i) -> void:
	_inc_dict(_seeds_planted, plant_id, 1)


func _on_cell_watered(cell: Vector2i) -> void:
	# Unique cells watered is typically the most useful metric.
	_watered_cells[cell] = true


func _on_plant_harvested(
	plant_id: StringName, harvest_item_id: StringName, count: int, _cell: Vector2i
) -> void:
	# Track "harvest actions" by plant, and yield as gained items.
	_inc_dict(_harvests_by_plant, plant_id, 1)
	_inc_dict(_items_gained, harvest_item_id, count)


func _on_shop_transaction(
	mode: StringName, item_id: StringName, count: int, _vendor_id: StringName
) -> void:
	if mode == &"buy":
		_inc_dict(_shop_buys, item_id, count)
	elif mode == &"sell":
		_inc_dict(_shop_sells, item_id, count)


func _on_quest_step_completed(quest_id: StringName, step_index: int) -> void:
	_quest_steps_completed.append({"quest_id": quest_id, "step_index": int(step_index)})


func _on_quest_completed(quest_id: StringName) -> void:
	_quests_completed.append(quest_id)


func _inc_dict(d: Dictionary, key: StringName, delta: int) -> void:
	if String(key).is_empty():
		return
	var prev := int(d.get(key, 0))
	d[key] = prev + int(delta)


func _get_player_money() -> int:
	var p := _get_player()
	if p != null and is_instance_valid(p) and "money" in p:
		return int(p.money)
	return 0


func _get_player() -> Node:
	# Prefer GameFlow's authoritative player lookup (groups-based).
	if Runtime != null and Runtime.game_flow != null and Runtime.game_flow.has_method("get_player"):
		return Runtime.game_flow.get_player()
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(Groups.PLAYER) as Node
