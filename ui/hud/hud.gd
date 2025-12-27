class_name HUD
extends CanvasLayer

@onready var hotbar: Hotbar = $Control/Hotbar

func _ready() -> void:
	if EventBus:
		EventBus.player_tool_equipped.connect(_on_tool_equipped)

	_find_and_sync_player()

func _find_and_sync_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Setup slots from player data
		if "hotbar_assignments" in player:
			hotbar.setup(player.hotbar_assignments)

		# Initial highlight
		if player.tool_node and player.tool_node.data:
			_on_tool_equipped(player.tool_node.data)

func _on_tool_equipped(tool_data: ToolData) -> void:
	hotbar.highlight_tool(tool_data)
