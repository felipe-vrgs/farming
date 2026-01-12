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

@onready var equipped_head_slot: EquipmentHotbarSlot = %EquippedHeadSlot
@onready var equipped_shirt_slot: EquipmentHotbarSlot = %EquippedShirtSlot
@onready var equipped_pants_slot: EquipmentHotbarSlot = %EquippedPantsSlot
@onready var item_popover: Control = %ItemPopover

var _equipment_slot_views: Dictionary = {}  # StringName slot -> EquipmentHotbarSlot

var player: Player = null
var _last_tab_index: int = 0
var _energy_component: EnergyComponent = null
var _last_money: int = -2147483648
var _money_poll_accum_s: float = 0.0
var _selected_inventory_index: int = -1
var _hover_inventory_index: int = -1
var _hover_equipment_slot: StringName = &""


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
		# Keep selection tracking for UI focus, but do NOT show item popover on keyboard focus.
		inventory_panel.slot_focused.connect(_on_inventory_slot_focused)
		if inventory_panel.has_signal("slot_double_clicked"):
			inventory_panel.slot_double_clicked.connect(_on_inventory_slot_double_clicked)
		if inventory_panel.has_signal("slot_hovered"):
			inventory_panel.slot_hovered.connect(_on_inventory_slot_hovered)
		if inventory_panel.has_signal("slot_unhovered"):
			inventory_panel.slot_unhovered.connect(_on_inventory_slot_unhovered)

	_collect_equipment_slot_views()
	_refresh_equipment_ui()
	_refresh_item_popover()


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
	_refresh_equipment_ui()
	_refresh_item_popover()


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
		var n := "Player"
		if player != null and is_instance_valid(player) and "display_name" in player:
			var raw := String(player.display_name).strip_edges()
			if not raw.is_empty():
				n = raw
		name_label.text = n

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
		_refresh_equipment_ui()
		_refresh_item_popover()


func _on_inventory_slot_focused(index: int) -> void:
	_selected_inventory_index = index
	_refresh_equipment_ui()


func _on_inventory_slot_changed(index: int) -> void:
	_selected_inventory_index = index
	_refresh_equipment_ui()


func _on_inventory_slot_double_clicked(index: int) -> void:
	if player == null or not is_instance_valid(player) or player.inventory == null:
		return
	if index < 0 or index >= player.inventory.slots.size():
		return
	var s: InventorySlot = player.inventory.slots[index]
	if s == null or s.item_data == null or s.count <= 0:
		return
	if s.item_data is ClothingItemData:
		if player.has_method("try_equip_clothing_from_inventory"):
			player.call("try_equip_clothing_from_inventory", index, &"")
		_refresh_player_summary()
		_refresh_equipment_ui()
		_refresh_item_popover()


func _on_inventory_slot_hovered(index: int) -> void:
	_hover_inventory_index = index
	_refresh_item_popover()


func _on_inventory_slot_unhovered(index: int) -> void:
	if _hover_inventory_index == index:
		_hover_inventory_index = -1
	_refresh_item_popover()


func _refresh_item_popover() -> void:
	if item_popover == null:
		return

	# PC UX: show the popover only on mouse hover.
	if not is_visible_in_tree():
		item_popover.visible = false
		return

	var has_player := player != null and is_instance_valid(player)

	var item: ItemData = null
	var count: int = 0
	var slot_name: StringName = &""
	var is_equipped := false
	var anchor_ctrl: Control = null

	# Priority: equipment hover over inventory hover (matches cursor position).
	if not String(_hover_equipment_slot).is_empty() and has_player:
		var slot_view: EquipmentHotbarSlot = (
			_equipment_slot_views.get(_hover_equipment_slot) as EquipmentHotbarSlot
		)
		if slot_view != null:
			anchor_ctrl = slot_view
			var equipped_id: StringName = player.get_equipped_item_id(_hover_equipment_slot)
			item = ItemResolver.resolve(equipped_id)
			count = 1 if item != null else 0
			slot_name = _hover_equipment_slot
			is_equipped = item != null

	if item == null:
		# Inventory hover fallback.
		var idx := _hover_inventory_index
		if not has_player or player.inventory == null:
			item_popover.visible = false
			return
		if idx < 0 or idx >= player.inventory.slots.size():
			item_popover.visible = false
			return

		var slot_data: InventorySlot = player.inventory.slots[idx]
		if slot_data == null or slot_data.item_data == null or slot_data.count <= 0:
			item_popover.visible = false
			return

		item = slot_data.item_data
		count = int(slot_data.count)
		if item != null and item.get_script() == ClothingItemData:
			var slot_any: Variant = item.get("slot") if item.has_method("get") else null
			slot_name = slot_any as StringName if slot_any is StringName else &""
			if not String(slot_name).is_empty():
				is_equipped = player.get_equipped_item_id(slot_name) == item.id
		if inventory_panel != null and inventory_panel.has_method("get_slot_control"):
			anchor_ctrl = inventory_panel.call("get_slot_control", idx) as Control

	if not item_popover.has_method("set_item"):
		item_popover.visible = false
		return
	item_popover.call("set_item", item, int(count), slot_name, bool(is_equipped))

	# Position near the hovered slot (best-effort).
	if anchor_ctrl != null:
		var rect := anchor_ctrl.get_global_rect()
		var pos := rect.position + Vector2(rect.size.x + 8.0, 0.0)

		var vp := get_viewport().get_visible_rect()
		var max_x: float = vp.size.x - item_popover.size.x - 6.0
		var max_y: float = vp.size.y - item_popover.size.y - 6.0
		pos.x = clampf(pos.x, 6.0, max_x)
		pos.y = clampf(pos.y, 6.0, max_y)
		item_popover.global_position = pos


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


func _refresh_equipment_ui() -> void:
	# Slot-driven refresh: adding a new equipment slot should only require adding an
	# EquipmentHotbarSlot with `equipment_slot` set (no changes here).
	if _equipment_slot_views.is_empty():
		_collect_equipment_slot_views()

	var has_player := player != null and is_instance_valid(player)
	for slot in _equipment_slot_views.keys():
		var slot_view: EquipmentHotbarSlot = _equipment_slot_views[slot] as EquipmentHotbarSlot
		if slot_view == null:
			continue

		var slot_label := _format_slot_label(slot as StringName)
		if not has_player:
			_set_equipped_slot(slot_view, null, "%s: (none)" % slot_label)
			continue

		var item_id: StringName = player.get_equipped_item_id(slot as StringName)
		var item: ItemData = ItemResolver.resolve(item_id)
		_set_equipped_slot(
			slot_view,
			item,
			"%s: %s" % [slot_label, item.display_name if item != null else "(none)"]
		)


func _set_equipped_slot(slot_view: EquipmentHotbarSlot, item: ItemData, tooltip: String) -> void:
	if slot_view == null:
		return
	slot_view.tooltip_text = tooltip
	slot_view.set_item(item, 1 if item != null else 0)


func _collect_equipment_slot_views() -> void:
	_equipment_slot_views.clear()
	_collect_equipment_slot_views_recursive(self)


func _collect_equipment_slot_views_recursive(node: Node) -> void:
	if node == null:
		return

	if node is EquipmentHotbarSlot:
		var s := node as EquipmentHotbarSlot
		if not String(s.equipment_slot).is_empty():
			_equipment_slot_views[s.equipment_slot] = s
			# Hook popover hover behavior.
			if not s.mouse_entered.is_connected(
				_on_equipment_slot_mouse_entered.bind(s.equipment_slot)
			):
				s.mouse_entered.connect(_on_equipment_slot_mouse_entered.bind(s.equipment_slot))
			if not s.mouse_exited.is_connected(
				_on_equipment_slot_mouse_exited.bind(s.equipment_slot)
			):
				s.mouse_exited.connect(_on_equipment_slot_mouse_exited.bind(s.equipment_slot))

	for child in node.get_children():
		_collect_equipment_slot_views_recursive(child)


func _format_slot_label(slot: StringName) -> String:
	var s := String(slot)
	if s.is_empty():
		return "Slot"
	return s.substr(0, 1).to_upper() + s.substr(1)


func _on_equipment_slot_mouse_entered(slot: StringName) -> void:
	_hover_equipment_slot = slot
	_refresh_item_popover()


func _on_equipment_slot_mouse_exited(slot: StringName) -> void:
	if _hover_equipment_slot == slot:
		_hover_equipment_slot = &""
	_refresh_item_popover()


func _on_equipped_slot_pressed(slot: StringName) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("try_unequip_clothing_to_inventory"):
		player.call("try_unequip_clothing_to_inventory", slot)
	else:
		player.set_equipped_item_id(slot, &"")
	_refresh_player_summary()
	_refresh_equipment_ui()


func _on_equipment_slot_drop(slot: StringName, data: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d := data as Dictionary
	if not d.has("index"):
		return
	var idx := int(d["index"])
	if player.has_method("try_equip_clothing_from_inventory"):
		player.call("try_equip_clothing_from_inventory", idx, slot)
	_refresh_player_summary()
	_refresh_equipment_ui()
