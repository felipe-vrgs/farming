class_name PlayerMenu
extends Control

enum Tab { INVENTORY = 0, QUESTS = 1, RELATIONSHIPS = 2 }

@onready var tabs: TabContainer = %Tabs
@onready var inventory_panel: Node = %InventoryPanel
@onready var quest_panel: Node = %QuestPanel
@onready var money_label: Label = %MoneyLabel

var player: Player = null
var _last_tab_index: int = 0


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure we capture input above gameplay.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Capture Tab/etc before the UI system uses it for focus navigation.
	set_process_input(true)
	if tabs != null:
		tabs.tab_changed.connect(_on_tab_changed)


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


func rebind(new_player: Player = null) -> void:
	player = new_player
	_refresh_money()
	if inventory_panel != null and inventory_panel.has_method("rebind"):
		inventory_panel.call("rebind", player)
	if quest_panel != null and quest_panel.has_method("rebind"):
		quest_panel.call("rebind")

	# Do not force a tab here; GameFlow decides via open_tab().


func _refresh_money() -> void:
	if money_label == null:
		return
	var amount := 0
	if player != null and "money" in player:
		amount = int(player.money)
	money_label.text = "Money: %d" % amount


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
