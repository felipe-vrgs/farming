class_name HUD
extends CanvasLayer

# We will hardcode the slots for now to match Player.gd input
var slots: Array[HotbarSlot] = []

@onready var slot_container: HBoxContainer = $Control/Hotbar/HBoxContainer


func _ready() -> void:
	# Wait for children to be ready
	setup_slots()

func setup_slots() -> void:
	slots.clear()
	for child in slot_container.get_children():
		if child is HotbarSlot:
			slots.append(child)

	if EventBus:
		EventBus.player_tool_equipped.connect(_on_tool_equipped)

	# Initial Setup - we need to know the tools.
	# Since tools are local to Player, we wait for player to emit or we grab them.
	# Ideally, we'd have a ToolRegistry or Player would push config.
	# For now, we will wait for the first equip or manually refresh if we find player.
	_find_and_sync_player()

func _find_and_sync_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# This relies on player properties being exposed or public
		# We'll just define the slots based on the known order:
		# 1: Shovel, 2: Seeds, 3: Water, 4: Axe
		if slots.size() >= 4:
			slots[0].set_tool(player.tool_shovel)
			slots[1].set_tool(player.tool_seeds) # TODO: Handle seed cycling
			slots[2].set_tool(player.tool_water)
			slots[3].set_tool(player.tool_axe)
			slots[4].set_tool(player.tool_hand)
		_on_tool_equipped(player.tool_hand)

func _on_tool_equipped(tool_data: ToolData) -> void:
	for slot in slots:
		slot.set_highlight(false)
		if slot.tool_data == tool_data:
			slot.set_highlight(true)
