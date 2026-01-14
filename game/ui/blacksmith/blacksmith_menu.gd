class_name BlacksmithMenu
extends Control

## BlacksmithMenu
## - Drop a tool into the input slot to preview the next upgrade and costs.
## - Applies upgrade by swapping the tool item in-place inside the player's inventory.

const _SFX_UPGRADE := preload("res://assets/sounds/effects/money.mp3")
const _ICON_MONEY := preload("res://assets/icons/money.png")

const _TOOLS_DIR := "res://game/entities/tools/data"
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
var _bound_inventory: InventoryData = null
var _selected_inventory: InventoryData = null
var _selected_index: int = -1

@onready var player_money_label: Label = %PlayerMoneyLabel
@onready var player_inventory_panel: InventoryPanel = %PlayerInventoryPanel
@onready var to_icon: TextureRect = %ToIcon
@onready var upgrade_name_label: Label = %UpgradeNameLabel
@onready var costs_list: VBoxContainer = %CostsList
@onready var upgrade_button: Button = %UpgradeButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if player_inventory_panel != null:
		player_inventory_panel.slot_clicked.connect(_on_inventory_slot_clicked)
	if upgrade_button != null:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)

	_recipes = _resolve_recipes_from_specs()
	_refresh_ui()


func setup(new_player: Node, new_vendor: Node = null) -> void:
	player = new_player
	vendor = new_vendor
	_selected_inventory = null
	_selected_index = -1

	if player_inventory_panel != null:
		player_inventory_panel.rebind(player as Player)
		call_deferred("_apply_inventory_filter")

	_bind_inventory(player.inventory if player != null and "inventory" in player else null)
	_refresh_ui()


func _bind_inventory(inv: InventoryData) -> void:
	if _bound_inventory != null and _bound_inventory.has_signal("contents_changed"):
		var cb := Callable(self, "_on_inventory_contents_changed")
		if _bound_inventory.is_connected("contents_changed", cb):
			_bound_inventory.disconnect("contents_changed", cb)

	_bound_inventory = inv
	if _bound_inventory != null and _bound_inventory.has_signal("contents_changed"):
		var cb2 := Callable(self, "_on_inventory_contents_changed")
		if not _bound_inventory.is_connected("contents_changed", cb2):
			_bound_inventory.connect("contents_changed", cb2)


func _on_inventory_contents_changed() -> void:
	if not _selection_is_valid():
		_selected_inventory = null
		_selected_index = -1
	_refresh_ui()
	call_deferred("_apply_inventory_filter")


func _apply_inventory_filter() -> void:
	if player_inventory_panel == null:
		return
	if player == null or not ("inventory" in player) or player.inventory == null:
		return
	var inv: InventoryData = player.inventory
	for i in range(inv.slots.size()):
		var ctrl := player_inventory_panel.get_slot_control(i)
		if ctrl == null or not (ctrl is HotbarSlot):
			continue
		var slot := inv.slots[i]
		var is_tool := slot != null and slot.item_data is ToolData
		var hs := ctrl as HotbarSlot
		hs.editable = is_tool
		hs.mouse_filter = Control.MOUSE_FILTER_STOP
		hs.modulate = Color(1, 1, 1, 1) if is_tool else Color(1, 1, 1, 0.35)


func _on_close_pressed() -> void:
	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.request_blacksmith_close()


func _on_inventory_slot_clicked(index: int) -> void:
	if player == null or not ("inventory" in player):
		return
	var inv: InventoryData = player.inventory
	_set_selected_slot(inv, index)

	if inv != null and index >= 0 and index < inv.slots.size():
		var slot := inv.slots[index]
		if slot == null or slot.item_data == null or not (slot.item_data is ToolData):
			_show_toast("Only tools can be upgraded.")


func _set_selected_slot(inv: InventoryData, index: int) -> void:
	if inv == null or index < 0 or index >= inv.slots.size():
		_selected_inventory = null
		_selected_index = -1
		_refresh_ui()
		return
	var slot := inv.slots[index]
	if slot == null or slot.item_data == null or not (slot.item_data is ToolData):
		_selected_inventory = null
		_selected_index = -1
		_refresh_ui()
		return
	_selected_inventory = inv
	_selected_index = index
	_refresh_ui()


func _on_upgrade_pressed() -> void:
	var r := _get_recipe_for_selected_tool()
	if r.is_empty():
		return
	_apply_upgrade(r)
	_refresh_ui()


func _refresh_ui() -> void:
	if player_money_label != null:
		player_money_label.text = "Money: %d" % _get_money(player)
	to_icon.visible = false

	var tool := _get_selected_tool()

	if to_icon != null:
		to_icon.texture = null

	if upgrade_name_label != null:
		upgrade_name_label.text = "Select a tool"

	_clear_cost_rows()
	if upgrade_button != null:
		upgrade_button.disabled = true

	if tool == null:
		return

	var r := _get_recipe_for_selected_tool()
	if r.is_empty():
		if upgrade_name_label != null:
			upgrade_name_label.text = "No upgrade available"
		return

	var to_tool: ToolData = r.get("to_tool")
	if to_icon != null and to_tool != null:
		to_icon.visible = true
		to_icon.texture = to_tool.icon
	if upgrade_name_label != null and to_tool != null:
		upgrade_name_label.text = "%s" % [to_tool.display_name]

	_render_costs(r)

	if upgrade_button != null:
		upgrade_button.disabled = not _can_upgrade(r)


func _render_costs(r: Dictionary) -> void:
	var money_cost := int(r.get("money_cost", 0))
	if money_cost > 0:
		var ok_money := _get_money(player) >= money_cost
		_add_cost_row(_ICON_MONEY, "%d" % money_cost, ok_money)

	var item_costs: Array = r.get("item_costs", [])
	for c in item_costs:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var item: ItemData = c.get("item")
		var cnt := int(c.get("count", 0))
		if item == null or cnt <= 0:
			continue
		var owned := 0
		if player != null and "inventory" in player and player.inventory != null:
			owned = player.inventory.count_item_id(item.id)
		var ok_item := owned >= cnt
		var text := "%s x%d (have %d)" % [item.display_name, cnt, owned]
		_add_cost_row(item.icon, text, ok_item)

	if money_cost <= 0 and item_costs.is_empty():
		_add_cost_row(null, "Free", true)


func _add_cost_row(icon: Texture2D, text: String, ok: bool) -> void:
	if costs_list == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(10, 10)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = icon

	var label := Label.new()
	label.text = text
	label.modulate = Color(0.70, 1.0, 0.70, 1.0) if ok else Color(1.0, 0.65, 0.65, 1.0)

	row.add_child(icon_rect)
	row.add_child(label)
	costs_list.add_child(row)


func _clear_cost_rows() -> void:
	if costs_list == null:
		return
	for child in costs_list.get_children():
		costs_list.remove_child(child)
		child.queue_free()


func _get_selected_tool() -> ToolData:
	if not _selection_is_valid():
		return null
	var slot := _selected_inventory.slots[_selected_index]
	if slot == null or slot.item_data == null:
		return null
	return slot.item_data as ToolData


func _selection_is_valid() -> bool:
	return (
		_selected_inventory != null
		and _selected_index >= 0
		and _selected_index < _selected_inventory.slots.size()
	)


func _get_recipe_for_selected_tool() -> Dictionary:
	var tool := _get_selected_tool()
	if tool == null:
		return {}
	for r in _recipes:
		var from_tool: ToolData = r.get("from_tool")
		if from_tool != null and from_tool.id == tool.id:
			return r
	return {}


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
	# Tiered tool resources live under:
	#   res://game/entities/tools/data/<tool>/<tool>_<tier>.tres
	# Example:
	#   res://game/entities/tools/data/axe/axe_gold.tres
	var parts := tool_id.split("_", false)
	var tool := parts[0] if parts.size() >= 1 else ""
	if tool.is_empty():
		return null
	var path := "%s/%s/%s.tres" % [_TOOLS_DIR, tool, tool_id]
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
