class_name PlayerMenu
extends Control

@onready var tabs: TabContainer = %Tabs
@onready var inventory_panel: Node = %InventoryPanel

var player: Player = null


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure we capture input above gameplay.
	mouse_filter = Control.MOUSE_FILTER_STOP


func rebind(new_player: Player = null) -> void:
	player = new_player
	if inventory_panel != null and inventory_panel.has_method("rebind"):
		inventory_panel.call("rebind", player)

	# Default to inventory tab when opening.
	if tabs != null:
		tabs.current_tab = 0
