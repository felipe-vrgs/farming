class_name BlacksmithMenu
extends Control

## BlacksmithMenu
## - Shows available tool upgrades and costs
## - Applies upgrade by swapping the tool item in-place inside the player's inventory

const _SFX_UPGRADE := preload("res://assets/sounds/effects/money.mp3")

const _TIERED_TOOLS_DIR := "res://game/entities/tools/data/tiers"
const _ITEMS_DIR := "res://game/entities/items/resources"

# Spec-driven so it's easy to extend later.
const _RECIPE_SPECS: Array[Dictionary] = [
	{
		"from": "axe_iron",
		"to": "axe_gold",
		"money": 100,
		"items": [{"item": "stone", "count": 10}],
	},
	{
		"from": "axe_gold",
		"to": "axe_platinum",
		"money": 250,
		"items": [{"item": "stone", "count": 25}],
	},
	{
		"from": "axe_platinum",
		"to": "axe_ruby",
		"money": 500,
		"items": [{"item": "stone", "count": 50}],
	},
	{
		"from": "pickaxe_iron",
		"to": "pickaxe_gold",
		"money": 100,
		"items": [{"item": "stone", "count": 10}],
	},
	{
		"from": "pickaxe_gold",
		"to": "pickaxe_platinum",
		"money": 250,
		"items": [{"item": "stone", "count": 25}],
	},
	{
		"from": "pickaxe_platinum",
		"to": "pickaxe_ruby",
		"money": 500,
		"items": [{"item": "stone", "count": 50}],
	},
]

var player: Node = null
var vendor: Node = null

var _recipes: Array[Dictionary] = []
var _selected_idx: int = -1

@onready var player_money_label: Label = %PlayerMoneyLabel
@onready var upgrades_list: ItemList = %UpgradesList
@onready var selected_icon: TextureRect = %SelectedIcon
@onready var selected_name_label: Label = %SelectedNameLabel
@onready var cost_label: Label = %CostLabel
@onready var upgrade_button: Button = %UpgradeButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if upgrades_list != null:
		upgrades_list.item_selected.connect(_on_upgrade_selected)
	if upgrade_button != null:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)

	_rebuild_recipe_list()
	_refresh_ui()


func setup(new_player: Node, new_vendor: Node = null) -> void:
	player = new_player
	vendor = new_vendor
	_selected_idx = -1
	_rebuild_recipe_list()
	_refresh_ui()


func _on_close_pressed() -> void:
	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.request_blacksmith_close()


func _on_upgrade_selected(index: int) -> void:
	_selected_idx = int(index)
	_refresh_ui()


func _on_upgrade_pressed() -> void:
	var r := _get_selected_recipe()
	if r.is_empty():
		return
	_apply_upgrade(r)
	_refresh_ui()


func _rebuild_recipe_list() -> void:
	_recipes = _resolve_recipes_from_specs()
	if upgrades_list == null:
		return
	upgrades_list.clear()
	for r in _recipes:
		var from_tool: ToolData = r.get("from_tool")
		var to_tool: ToolData = r.get("to_tool")
		var money_cost := int(r.get("money_cost", 0))
		var text := (
			"%s → %s"
			% [
				from_tool.display_name if from_tool != null else "Tool",
				to_tool.display_name if to_tool != null else "Upgrade",
			]
		)
		if money_cost > 0:
			text = "%s  (%d money)" % [text, money_cost]
		upgrades_list.add_item(text)

	# Default selection: first available.
	if _selected_idx < 0 and upgrades_list.item_count > 0:
		_selected_idx = 0
		upgrades_list.select(0)


func _refresh_ui() -> void:
	if player_money_label != null:
		player_money_label.text = "Money: %d" % _get_money(player)

	var r := _get_selected_recipe()
	if selected_icon != null:
		selected_icon.texture = null
	if selected_name_label != null:
		selected_name_label.text = "Select an upgrade"
	if cost_label != null:
		cost_label.text = ""
	if upgrade_button != null:
		upgrade_button.disabled = true

	if r.is_empty():
		return

	var from_tool: ToolData = r.get("from_tool")
	var to_tool: ToolData = r.get("to_tool")
	if selected_icon != null and to_tool != null:
		selected_icon.texture = to_tool.icon
	if selected_name_label != null and from_tool != null and to_tool != null:
		selected_name_label.text = "%s → %s" % [from_tool.display_name, to_tool.display_name]

	if cost_label != null:
		cost_label.text = _format_cost_text(r)

	if upgrade_button != null:
		upgrade_button.disabled = not _can_upgrade(r)


func _format_cost_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	var money_cost := int(r.get("money_cost", 0))
	if money_cost > 0:
		parts.append("%d money" % money_cost)
	var item_costs: Array = r.get("item_costs", [])
	for c in item_costs:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var item: ItemData = c.get("item")
		var cnt := int(c.get("count", 0))
		if item == null or cnt <= 0:
			continue
		parts.append("%s x%d" % [item.display_name, cnt])
	if parts.is_empty():
		return "Cost: Free"
	return "Cost: " + ", ".join(parts)


func _get_selected_recipe() -> Dictionary:
	if _selected_idx < 0 or _selected_idx >= _recipes.size():
		return {}
	return _recipes[_selected_idx]


func _can_upgrade(r: Dictionary) -> bool:
	if player == null or not ("inventory" in player) or player.inventory == null:
		return false
	var inv: InventoryData = player.inventory

	var from_tool: ToolData = r.get("from_tool")
	var to_tool: ToolData = r.get("to_tool")
	if from_tool == null or to_tool == null:
		return false

	if inv.find_slot_with_item_id(from_tool.id) < 0:
		return false

	var money_cost := int(r.get("money_cost", 0))
	if _get_money(player) < money_cost:
		return false

	var item_costs: Array = r.get("item_costs", [])
	for c in item_costs:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var item: ItemData = c.get("item")
		var cnt := int(c.get("count", 0))
		if item == null or cnt <= 0:
			continue
		if inv.count_item_id(item.id) < cnt:
			return false

	return true


func _apply_upgrade(r: Dictionary) -> void:
	if not _can_upgrade(r):
		_show_toast("Missing requirements.")
		return

	var inv: InventoryData = player.inventory
	var from_tool: ToolData = r.get("from_tool")
	var to_tool: ToolData = r.get("to_tool")
	var money_cost := int(r.get("money_cost", 0))
	var item_costs: Array = r.get("item_costs", [])

	# Deduct money first.
	_set_money(player, _get_money(player) - money_cost)

	# Remove required items.
	for c in item_costs:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var item: ItemData = c.get("item")
		var cnt := int(c.get("count", 0))
		if item == null or cnt <= 0:
			continue
		inv.remove_item_id(item.id, cnt)

	# Swap the tool in-place (avoids inventory-full issues).
	var slot_idx := inv.find_slot_with_item_id(from_tool.id)
	if slot_idx < 0:
		# Should not happen (we validated), but avoid losing money/items.
		_show_toast("Tool not found.")
		return

	var slot := inv.slots[slot_idx]
	if slot == null:
		slot = InventorySlot.new()
		inv.slots[slot_idx] = slot
	slot.item_data = to_tool
	slot.count = 1
	inv.contents_changed.emit()

	# Feedback
	if SFXManager != null:
		SFXManager.play_ui(_SFX_UPGRADE, player.global_position, Vector2.ONE, -6.0)
	_show_toast("Upgraded!")


func _resolve_recipes_from_specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spec in _RECIPE_SPECS:
		var from_id := String(spec.get("from", "")).strip_edges()
		var to_id := String(spec.get("to", "")).strip_edges()
		if from_id.is_empty() or to_id.is_empty():
			continue

		var from_tool := _load_tool(from_id)
		var to_tool := _load_tool(to_id)
		if from_tool == null or to_tool == null:
			continue

		var r := {}
		r["from_tool"] = from_tool
		r["to_tool"] = to_tool
		r["money_cost"] = int(spec.get("money", 0))

		var item_costs: Array[Dictionary] = []
		var items_any: Variant = spec.get("items", [])
		var items: Array = items_any if items_any is Array else []
		for c_any in items:
			if typeof(c_any) != TYPE_DICTIONARY:
				continue
			var c := c_any as Dictionary
			var item_key := String(c.get("item", "")).strip_edges()
			var cnt := int(c.get("count", 0))
			if item_key.is_empty() or cnt <= 0:
				continue
			var item := _load_item(item_key)
			if item == null:
				continue
			item_costs.append({"item": item, "count": cnt})
		r["item_costs"] = item_costs

		out.append(r)

	return out


func _load_tool(tool_id: String) -> ToolData:
	var path := "%s/%s.tres" % [_TIERED_TOOLS_DIR, tool_id]
	var res := load(path)
	return res as ToolData


func _load_item(item_key: String) -> ItemData:
	# item_key matches filename under res://game/entities/items/resources (without .tres)
	var path := "%s/%s.tres" % [_ITEMS_DIR, item_key]
	var res := load(path)
	return res as ItemData


func _get_money(n: Node) -> int:
	if n != null and "money" in n:
		return int(n.money)
	return 0


func _set_money(n: Node, value: int) -> void:
	if n != null and "money" in n:
		n.money = int(maxi(0, value))


func _show_toast(text: String) -> void:
	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast(text)
