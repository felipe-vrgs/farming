class_name PlayerMenu
extends Control

enum Tab { INVENTORY = 0, QUESTS = 1, RELATIONSHIPS = 2 }

@onready var tabs: TabContainer = %Tabs
@onready var inventory_panel: InventoryPanel = %InventoryPanel
@onready var quest_panel: Node = %QuestPanel
@onready var relationships_panel: Node = %RelationshipsPanel
@onready var money_label: Label = %MoneyLabel
@onready var portrait_visual: CharacterVisual = %PortraitVisual
@onready var name_label: Label = %NameLabel
@onready var energy_label: Label = %EnergyLabel

@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemName
@onready var item_desc_label: Label = %ItemDesc
@onready var value_label: Label = %ValueLabel
@onready var equip_button: Button = %EquipButton
@onready var equipped_shirt_button: TextureButton = %EquippedShirtButton
@onready var equipped_pants_button: TextureButton = %EquippedPantsButton

const _EQUIP_SLOT_SHIRT: StringName = &"shirt"
const _EQUIP_SLOT_PANTS: StringName = &"pants"

var player: Player = null
var _last_tab_index: int = 0
var _energy_component: EnergyComponent = null
var _last_money: int = -2147483648
var _money_poll_accum_s: float = 0.0
var _selected_inventory_index: int = -1


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure we capture input above gameplay.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Capture Tab/etc before the UI system uses it for focus navigation.
	set_process_input(true)
	set_process(true)
	if tabs != null:
		tabs.tab_changed.connect(_on_tab_changed)
	if inventory_panel != null:
		inventory_panel.slot_clicked.connect(_on_inventory_slot_changed)
		inventory_panel.slot_focused.connect(_on_inventory_slot_changed)

	if equip_button != null:
		equip_button.pressed.connect(_on_equip_button_pressed)
	if equipped_shirt_button != null:
		equipped_shirt_button.pressed.connect(_on_equipped_slot_pressed.bind(_EQUIP_SLOT_SHIRT))
	if equipped_pants_button != null:
		equipped_pants_button.pressed.connect(_on_equipped_slot_pressed.bind(_EQUIP_SLOT_PANTS))

	_update_item_details(-1)
	_refresh_equipment_ui()


func _input(event: InputEvent) -> void:
	if event == null or not is_visible_in_tree():
		return

	# Close the player menu with Tab.
	# We use _input (not _unhandled_input) so TabContainer can't swallow it first.
	if event.is_action_pressed(&"open_player_menu", false, true):
		if Runtime != null and Runtime.game_flow != null:
			Runtime.game_flow.toggle_player_menu()
			get_viewport().set_input_as_handled()
		return

	# While open: allow switching tabs with direct-open actions.
	if event.is_action_pressed(&"open_player_menu_inventory", false, true):
		if tabs != null and tabs.current_tab == int(Tab.INVENTORY):
			if Runtime != null and Runtime.game_flow != null:
				Runtime.game_flow.toggle_player_menu()
		else:
			open_tab(Tab.INVENTORY)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"open_player_menu_quests", false, true):
		if tabs != null and tabs.current_tab == int(Tab.QUESTS):
			if Runtime != null and Runtime.game_flow != null:
				Runtime.game_flow.toggle_player_menu()
		else:
			open_tab(Tab.QUESTS)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"open_player_menu_relationships", false, true):
		if tabs != null and tabs.current_tab == int(Tab.RELATIONSHIPS):
			if Runtime != null and Runtime.game_flow != null:
				Runtime.game_flow.toggle_player_menu()
		else:
			open_tab(Tab.RELATIONSHIPS)
		get_viewport().set_input_as_handled()
		return


func rebind(new_player: Player = null) -> void:
	# Disconnect previous player signals.
	if _energy_component != null and is_instance_valid(_energy_component):
		var cb := Callable(self, "_on_energy_changed")
		if _energy_component.is_connected("energy_changed", cb):
			_energy_component.disconnect("energy_changed", cb)

	player = new_player
	_last_money = -2147483648
	_refresh_money()
	_refresh_player_summary()
	if inventory_panel != null and inventory_panel.has_method("rebind"):
		inventory_panel.call("rebind", player)
	if quest_panel != null and quest_panel.has_method("rebind"):
		quest_panel.call("rebind")
	if relationships_panel != null and relationships_panel.has_method("rebind"):
		relationships_panel.call("rebind")

	# Keep the energy label live while the menu is open.
	_energy_component = player.energy_component if player != null else null
	if _energy_component != null and is_instance_valid(_energy_component):
		var cb := Callable(self, "_on_energy_changed")
		if not _energy_component.is_connected("energy_changed", cb):
			_energy_component.connect("energy_changed", cb)

	# Do not force a tab here; GameFlow decides via open_tab().
	_selected_inventory_index = _find_first_item_index()
	_update_item_details(_selected_inventory_index)
	_refresh_equipment_ui()


func _refresh_money() -> void:
	if money_label == null:
		return
	var amount := 0
	if player != null and "money" in player:
		amount = int(player.money)
	if amount == _last_money:
		return
	_last_money = amount
	money_label.text = "%d" % amount


func _process(delta: float) -> void:
	# Money can change while the menu is open (quest rewards, shop, etc.).
	# There is no central money_changed signal, so we do a lightweight poll.
	if not is_visible_in_tree():
		_money_poll_accum_s = 0.0
		return
	_money_poll_accum_s += float(delta)
	if _money_poll_accum_s < 0.25:
		return
	_money_poll_accum_s = 0.0
	_refresh_money()


func _refresh_player_summary() -> void:
	if name_label != null:
		# TODO: if you add a proper player name later, use it here.
		name_label.text = "Player"

	# Portrait: render layered character visuals.
	if portrait_visual != null:
		# Menu is typically shown while gameplay is paused; ensure portrait continues animating.
		portrait_visual.process_mode = Node.PROCESS_MODE_ALWAYS
		var ok := false
		if player != null and is_instance_valid(player) and "character_visual" in player:
			var cv: CharacterVisual = player.character_visual
			if cv != null and cv.appearance != null:
				portrait_visual.appearance = cv.appearance
				# Default to idle_front for portrait.
				portrait_visual.play_resolved(&"idle_front")
				portrait_visual.visible = true
				ok = true
		if not ok:
			portrait_visual.visible = false

	_refresh_equipment_ui()

	# Energy
	if energy_label != null:
		var cur := -1.0
		var max_v := -1.0
		if player != null and is_instance_valid(player) and player.energy_component != null:
			cur = float(player.energy_component.current_energy)
			max_v = float(player.energy_component.max_energy)
		if cur >= 0.0 and max_v >= 0.0:
			energy_label.text = "Energy: %d/%d" % [int(cur), int(max_v)]
		else:
			energy_label.text = "Energy: -/-"


func _on_energy_changed(_current: float, _max: float) -> void:
	_refresh_player_summary()


func open_tab(tab_index: int) -> void:
	if tabs == null:
		return
	var idx := int(tab_index)
	if idx < 0:
		idx = _last_tab_index
	# Clamp to existing tabs.
	idx = clampi(idx, 0, maxi(0, tabs.get_tab_count() - 1))
	tabs.current_tab = idx
	_last_tab_index = idx


func get_current_tab() -> int:
	if tabs == null:
		return -1
	return int(tabs.current_tab)


func _on_tab_changed(tab: int) -> void:
	_last_tab_index = int(tab)
	if int(tab) == int(Tab.INVENTORY):
		_selected_inventory_index = _find_first_item_index()
		_update_item_details(_selected_inventory_index)
		_refresh_equipment_ui()


func _on_inventory_slot_changed(index: int) -> void:
	_selected_inventory_index = index
	_update_item_details(index)
	_refresh_equipment_ui()


func _find_first_item_index() -> int:
	if player == null or not is_instance_valid(player):
		return -1
	if not ("inventory" in player) or player.inventory == null:
		return -1
	var slots: Array = player.inventory.slots
	for i in range(slots.size()):
		var s: InventorySlot = slots[i]
		if s != null and s.item_data != null and s.count > 0:
			return i
	return -1


func _update_item_details(index: int) -> void:
	if item_name_label == null or item_desc_label == null:
		return

	var item: ItemData = null
	var count := 0

	if (
		player != null
		and is_instance_valid(player)
		and ("inventory" in player)
		and player.inventory != null
		and index >= 0
		and index < player.inventory.slots.size()
	):
		var slot: InventorySlot = player.inventory.slots[index]
		if slot != null and slot.item_data != null and slot.count > 0:
			item = slot.item_data
			count = int(slot.count)

	if item == null:
		if item_icon != null:
			item_icon.texture = null
		item_name_label.text = "Select an item"
		item_desc_label.text = " "
		if value_label != null:
			value_label.text = "Value: -"
		_refresh_equip_button(null)
		return

	if item_icon != null:
		item_icon.texture = item.icon

	item_name_label.text = "%s (x%d)" % [item.display_name, count]

	var desc := String(item.description).strip_edges()
	if desc.is_empty():
		desc = "(No description)"
	if item_desc_label != null:
		item_desc_label.tooltip_text = desc
		var short := desc
		if short.length() > 80:
			short = "%s…" % short.substr(0, 80)
		item_desc_label.text = short

	if value_label != null:
		var buy := int(item.buy_price)
		var sell := int(item.sell_price)
		if buy == sell:
			value_label.text = "Value: %d" % sell
		else:
			value_label.text = "Sell: %d   Buy: %d" % [sell, buy]

	_refresh_equip_button(item)


func _refresh_equipment_ui() -> void:
	_refresh_equip_button(_get_selected_item())

	if player == null or not is_instance_valid(player):
		_set_equipped_button(equipped_shirt_button, null, "Shirt: (none)")
		_set_equipped_button(equipped_pants_button, null, "Pants: (none)")
		return

	var shirt_id: StringName = player.get_equipped_item_id(_EQUIP_SLOT_SHIRT)
	var pants_id: StringName = player.get_equipped_item_id(_EQUIP_SLOT_PANTS)

	var shirt_item: ItemData = ItemResolver.resolve(shirt_id)
	var pants_item: ItemData = ItemResolver.resolve(pants_id)

	_set_equipped_button(
		equipped_shirt_button,
		shirt_item,
		"Shirt: %s" % (shirt_item.display_name if shirt_item != null else "(none)")
	)
	_set_equipped_button(
		equipped_pants_button,
		pants_item,
		"Pants: %s" % (pants_item.display_name if pants_item != null else "(none)")
	)


func _set_equipped_button(btn: TextureButton, item: ItemData, tooltip: String) -> void:
	if btn == null:
		return
	btn.tooltip_text = tooltip
	btn.texture_normal = item.icon if (item != null and item.icon is Texture2D) else null


func _get_selected_item() -> ItemData:
	if (
		player == null
		or not is_instance_valid(player)
		or player.inventory == null
		or _selected_inventory_index < 0
		or _selected_inventory_index >= player.inventory.slots.size()
	):
		return null
	var slot: InventorySlot = player.inventory.slots[_selected_inventory_index]
	if slot == null or slot.item_data == null or slot.count <= 0:
		return null
	return slot.item_data


func _refresh_equip_button(item: ItemData) -> void:
	if equip_button == null:
		return
	if player == null or not is_instance_valid(player):
		equip_button.visible = true
		equip_button.disabled = true
		equip_button.text = "Equip"
		return
	if item == null:
		equip_button.visible = true
		equip_button.disabled = true
		equip_button.text = "Equip"
		return
	if item.get_script() != ClothingItemData:
		equip_button.visible = true
		equip_button.disabled = true
		equip_button.text = "Equip"
		return

	var slot_any: Variant = item.get("slot") if item.has_method("get") else null
	var slot: StringName = slot_any as StringName if slot_any is StringName else &""
	if String(slot).is_empty():
		equip_button.visible = true
		equip_button.disabled = true
		equip_button.text = "Equip"
		return

	var equipped_id: StringName = player.get_equipped_item_id(slot)
	var is_equipped := equipped_id == item.id
	equip_button.visible = true
	equip_button.text = "Unequip" if is_equipped else "Equip"
	equip_button.disabled = false


func _on_equip_button_pressed() -> void:
	var item := _get_selected_item()
	if item == null:
		return
	if player == null or not is_instance_valid(player):
		return
	if item.get_script() != ClothingItemData:
		return

	var slot_any: Variant = item.get("slot") if item.has_method("get") else null
	var slot: StringName = slot_any as StringName if slot_any is StringName else &""
	if String(slot).is_empty():
		return

	var equipped_id: StringName = player.get_equipped_item_id(slot)
	if equipped_id == item.id:
		player.set_equipped_item_id(slot, &"")
	else:
		player.set_equipped_item_id(slot, item.id)

	# Refresh UI + portrait after applying.
	_refresh_player_summary()
	_refresh_equipment_ui()


func _on_equipped_slot_pressed(slot: StringName) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set_equipped_item_id(slot, &"")
	_refresh_player_summary()
	_refresh_equipment_ui()
