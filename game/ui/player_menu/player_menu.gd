class_name PlayerMenu
extends Control

@onready var tabs: TabContainer = %Tabs
@onready var inventory_panel: Node = %InventoryPanel
@onready var money_label: Label = %MoneyLabel

var player: Player = null


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure we capture input above gameplay.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Capture Tab/etc before the UI system uses it for focus navigation.
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event == null or not is_visible_in_tree():
		return

	# Close the player menu with the same action that opened it (Tab by default).
	# We use _input (not _unhandled_input) so TabContainer can't swallow it first.
	if event.is_action_pressed(&"open_player_menu", false, true):
		if Runtime != null and Runtime.game_flow != null:
			Runtime.game_flow.toggle_player_menu()
			get_viewport().set_input_as_handled()


func rebind(new_player: Player = null) -> void:
	player = new_player
	_refresh_money()
	if inventory_panel != null and inventory_panel.has_method("rebind"):
		inventory_panel.call("rebind", player)

	# Default to inventory tab when opening.
	if tabs != null:
		tabs.current_tab = 0


func _refresh_money() -> void:
	if money_label == null:
		return
	var amount := 0
	if player != null and "money" in player:
		amount = int(player.money)
	money_label.text = "Money: %d" % amount
