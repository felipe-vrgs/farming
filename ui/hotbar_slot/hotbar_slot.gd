class_name HotbarSlot
extends PanelContainer

var tool_data: ToolData
var item_data: ItemData

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect
@onready var label: Label = $MarginContainer/Label
@onready var highlight: ReferenceRect = $ReferenceRect


func _ready() -> void:
	highlight.visible = false
	label.text = ""

func set_tool(data: ToolData) -> void:
	tool_data = data
	item_data = null
	if data and data.texture:
		texture_rect.texture = data.texture
	else:
		texture_rect.texture = null
	label.text = ""

func set_item(data: ItemData, count: int = 1) -> void:
	item_data = data
	tool_data = null
	if data and data.texture:
		texture_rect.texture = data.texture
	else:
		texture_rect.texture = null
	if count > 1:
		label.text = str(count)
	else:
		label.text = ""

func set_highlight(active: bool) -> void:
	highlight.visible = active

