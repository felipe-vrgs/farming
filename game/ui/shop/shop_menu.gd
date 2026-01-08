class_name ShopMenu
extends Control

## Basic buy/sell UI between a player and a vendor (NPC).
## This menu is meant to be shown via GameFlow SHOPPING state.

var player: Node = null
var vendor: Node = null

var _selected_player_slot: int = -1
var _selected_vendor_slot: int = -1

@onready var player_inventory_panel: InventoryPanel = %PlayerInventoryPanel
@onready var vendor_inventory_panel: InventoryPanel = %VendorInventoryPanel
@onready var player_money_label: Label = %PlayerMoneyLabel
@onready var vendor_money_label: Label = %VendorMoneyLabel
@onready var selected_item_label: Label = %SelectedItemLabel
@onready var qty_spin: SpinBox = %QtySpin
@onready var buy_button: Button = %BuyButton
@onready var sell_button: Button = %SellButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if player_inventory_panel != null:
		player_inventory_panel.slot_clicked.connect(_on_player_slot_clicked)
	if vendor_inventory_panel != null:
		vendor_inventory_panel.slot_clicked.connect(_on_vendor_slot_clicked)

	if buy_button != null:
		buy_button.pressed.connect(_on_buy_pressed)
	if sell_button != null:
		sell_button.pressed.connect(_on_sell_pressed)
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)

	_refresh_ui()


func setup(new_player: Node, new_vendor: Node) -> void:
	player = new_player
	vendor = new_vendor
	_selected_player_slot = -1
	_selected_vendor_slot = -1

	if player_inventory_panel != null:
		player_inventory_panel.rebind(player as Player)
	if vendor_inventory_panel != null:
		var inv: InventoryData = (
			vendor.inventory if vendor != null and "inventory" in vendor else null
		)
		vendor_inventory_panel.rebind_inventory(inv)

	_refresh_ui()


func _on_player_slot_clicked(index: int) -> void:
	_selected_player_slot = index
	_selected_vendor_slot = -1
	if vendor_inventory_panel != null:
		vendor_inventory_panel.set_selected_index(-1)
	_refresh_ui()


func _on_vendor_slot_clicked(index: int) -> void:
	_selected_vendor_slot = index
	_selected_player_slot = -1
	if player_inventory_panel != null:
		player_inventory_panel.set_selected_index(-1)
	_refresh_ui()


func _on_buy_pressed() -> void:
	_buy_selected()


func _on_sell_pressed() -> void:
	_sell_selected()


func _on_close_pressed() -> void:
	if Runtime != null and Runtime.game_flow != null:
		Runtime.game_flow.request_shop_close()


func _refresh_ui() -> void:
	var p_money := _get_money(player)
	var v_money := _get_money(vendor)

	if player_money_label != null:
		player_money_label.text = "Player: %d" % p_money
	if vendor_money_label != null:
		vendor_money_label.text = "Vendor: %d" % v_money

	var sel_text := "Select an item to buy/sell"
	var can_buy := false
	var can_sell := false

	if _selected_vendor_slot >= 0:
		var slot := _get_slot(vendor, _selected_vendor_slot)
		if slot != null and slot.item_data != null and slot.count > 0:
			var price := _get_buy_price(slot.item_data)
			sel_text = "%s (x%d) - Buy: %d" % [slot.item_data.display_name, slot.count, price]
			can_buy = true

	if _selected_player_slot >= 0:
		var slot2 := _get_slot(player, _selected_player_slot)
		if slot2 != null and slot2.item_data != null and slot2.count > 0:
			var price2 := _get_sell_price(slot2.item_data)
			sel_text = "%s (x%d) - Sell: %d" % [slot2.item_data.display_name, slot2.count, price2]
			can_sell = true

	if selected_item_label != null:
		selected_item_label.text = sel_text

	if buy_button != null:
		buy_button.disabled = not can_buy
	if sell_button != null:
		sell_button.disabled = not can_sell


func _buy_selected() -> void:
	var inventories := _get_inventories()
	if inventories.size() < 2:
		return
	var p_inv: InventoryData = inventories[0]
	var v_inv: InventoryData = inventories[1]

	var slot := _get_slot(vendor, _selected_vendor_slot)
	if slot == null or slot.item_data == null or slot.count <= 0:
		return
	var item: ItemData = slot.item_data

	var unit_price: int = _get_buy_price(item)
	var desired: int = maxi(1, int(qty_spin.value) if qty_spin != null else 1)
	var affordable: int = desired
	if unit_price > 0:
		affordable = mini(affordable, int(floor(float(_get_money(player)) / float(unit_price))))
	var to_try: int = mini(desired, mini(slot.count, affordable))
	if to_try <= 0:
		_show_toast("Not enough money.")
		_refresh_ui()
		return

	# Move items: vendor -> player.
	var removed: int = v_inv.remove_from_slot(_selected_vendor_slot, to_try)
	if removed <= 0:
		_refresh_ui()
		return

	var remainder: int = p_inv.add_item(item, removed)
	var moved: int = removed - remainder
	if remainder > 0:
		# Put leftovers back into vendor inventory.
		v_inv.add_item(item, remainder)

	if moved <= 0:
		_show_toast("Inventory full.")
		_refresh_ui()
		return

	_set_money(player, _get_money(player) - moved * unit_price)
	_set_money(vendor, _get_money(vendor) + moved * unit_price)

	if EventBus != null and item != null and not String(item.id).is_empty():
		EventBus.shop_transaction.emit(&"buy", item.id, moved, _get_vendor_id())

	if moved < to_try:
		_show_toast("Bought %d (partial: inventory full)." % moved)
	else:
		_show_toast("Bought %d." % moved)

	_refresh_ui()


func _sell_selected() -> void:
	var inventories := _get_inventories()
	if inventories.size() < 2:
		return
	var p_inv: InventoryData = inventories[0]
	var v_inv: InventoryData = inventories[1]

	var slot := _get_slot(player, _selected_player_slot)
	if slot == null or slot.item_data == null or slot.count <= 0:
		return
	var item: ItemData = slot.item_data

	var unit_price: int = _get_sell_price(item)
	var desired: int = maxi(1, int(qty_spin.value) if qty_spin != null else 1)
	var payable: int = desired
	if unit_price > 0:
		payable = mini(payable, int(floor(float(_get_money(vendor)) / float(unit_price))))
	var to_try: int = mini(desired, mini(slot.count, payable))
	if to_try <= 0:
		_show_toast("Vendor doesn't have enough money.")
		_refresh_ui()
		return

	# Move items: player -> vendor.
	var removed: int = p_inv.remove_from_slot(_selected_player_slot, to_try)
	if removed <= 0:
		_refresh_ui()
		return

	var remainder: int = v_inv.add_item(item, removed)
	var moved: int = removed - remainder
	if remainder > 0:
		# Put leftovers back into player inventory.
		p_inv.add_item(item, remainder)

	if moved <= 0:
		_show_toast("Vendor inventory full.")
		_refresh_ui()
		return

	_set_money(vendor, _get_money(vendor) - moved * unit_price)
	_set_money(player, _get_money(player) + moved * unit_price)

	if EventBus != null and item != null and not String(item.id).is_empty():
		EventBus.shop_transaction.emit(&"sell", item.id, moved, _get_vendor_id())

	if moved < to_try:
		_show_toast("Sold %d (partial: vendor inventory full)." % moved)
	else:
		_show_toast("Sold %d." % moved)

	_refresh_ui()


func _get_inventories() -> Array[InventoryData]:
	# Returns [player_inventory, vendor_inventory]
	if player == null or vendor == null:
		return []

	var p_inv: InventoryData = player.inventory if "inventory" in player else null
	var v_inv: InventoryData = vendor.inventory if "inventory" in vendor else null
	if p_inv == null or v_inv == null:
		return []

	return [p_inv, v_inv]


func _get_slot(inv_owner: Node, index: int) -> InventorySlot:
	if inv_owner == null or not ("inventory" in inv_owner):
		return null
	var inv: InventoryData = inv_owner.inventory
	if inv == null:
		return null
	if index < 0 or index >= inv.slots.size():
		return null
	return inv.slots[index]


func _get_money(n: Node) -> int:
	if n != null and "money" in n:
		return int(n.money)
	return 0


func _set_money(n: Node, value: int) -> void:
	if n != null and "money" in n:
		n.money = int(maxi(0, value))


func _get_vendor_id() -> StringName:
	# Best-effort stable vendor id for quests/analytics.
	if vendor == null:
		return &""
	var ac: Node = null
	if vendor is Node:
		ac = (vendor as Node).get_node_or_null(NodePath("Components/AgentComponent"))
		if ac == null:
			ac = (vendor as Node).get_node_or_null(NodePath("AgentComponent"))
	if ac != null and "agent_id" in ac:
		return ac.agent_id
	if "npc_config" in vendor and vendor.npc_config != null and "npc_id" in vendor.npc_config:
		return vendor.npc_config.npc_id
	return StringName(String(vendor.name))


func _get_buy_price(item: ItemData) -> int:
	if item == null:
		return 0
	# Support older ItemData resources without price fields.
	var p_val: Variant = item.get("buy_price")
	if typeof(p_val) == TYPE_INT or typeof(p_val) == TYPE_FLOAT:
		return int(p_val)
	return 1


func _get_sell_price(item: ItemData) -> int:
	if item == null:
		return 0
	var p_val: Variant = item.get("sell_price")
	if typeof(p_val) == TYPE_INT or typeof(p_val) == TYPE_FLOAT:
		return int(p_val)
	# Fallback: sell at half of buy price (min 1).
	return maxi(1, int(floor(float(_get_buy_price(item)) / 2.0)))


func _show_toast(text: String) -> void:
	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast(text)
