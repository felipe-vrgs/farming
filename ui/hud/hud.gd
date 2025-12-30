class_name HUD
extends CanvasLayer

var player: Player = null

@onready var hotbar: Hotbar = $Control/Hotbar

func _ready() -> void:
	if EventBus:
		EventBus.player_tool_equipped.connect(_on_tool_equipped)

	_find_and_sync_player()

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_find_and_sync_player()

func _find_and_sync_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		# Setup slots from player data
		if "tools" in player.tool_manager:
			var hotkeys = []
			if player.player_input_config:
				hotkeys = [
					_get_key_text(player.player_input_config.action_hotbar_1),
					_get_key_text(player.player_input_config.action_hotbar_2),
					_get_key_text(player.player_input_config.action_hotbar_3),
					_get_key_text(player.player_input_config.action_hotbar_4),
					_get_key_text(player.player_input_config.action_hotbar_5),
				]
			hotbar.setup(player.tool_manager.tools, hotkeys)

		# Initial highlight
		if player.tool_node and player.tool_node.data:
			_on_tool_equipped(player.tool_node.data)

func _get_key_text(action: StringName) -> String:
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return ""

func _on_tool_equipped(tool_data: ToolData) -> void:
	hotbar.highlight_tool(tool_data)
