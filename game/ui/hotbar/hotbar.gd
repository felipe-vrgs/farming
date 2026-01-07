class_name Hotbar
extends MarginContainer

const SLOT_SCENE = preload("res://game/ui/hotbar_slot/hotbar_slot.tscn")

@export var slot_size: Vector2 = Vector2(20, 20)

@onready var container: HBoxContainer = $HBoxContainer


func setup(items: Array, hotkeys: Array = []) -> void:
	# Clear existing slots
	for child in container.get_children():
		child.queue_free()

	# Create new slots
	for i in range(items.size()):
		var item = items[i]
		var slot = SLOT_SCENE.instantiate()
		slot.custom_minimum_size = slot_size
		container.add_child(slot)

		if i < hotkeys.size():
			slot.set_hotkey(hotkeys[i])

		if item is ToolData:
			slot.set_tool(item)
		elif item is ItemData:
			slot.set_item(item)
		elif item == null:
			# Empty slot support if needed
			pass


func highlight_tool(tool_data: ToolData) -> void:
	for slot in container.get_children():
		if not slot is HotbarSlot:
			continue

		slot.set_highlight(false)
		if slot.tool_data == tool_data:
			slot.set_highlight(true)
