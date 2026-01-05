class_name HotbarSlot
extends PanelContainer

var tool_data: ToolData
var item_data: ItemData

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect
@onready var label: Label = $MarginContainer/Label
@onready var hotkey_label: Label = $MarginContainer/HotkeyLabel
@onready var highlight: ReferenceRect = $ReferenceRect


func _ready() -> void:
	highlight.visible = false
	label.text = ""
	hotkey_label.text = ""


func set_hotkey(text: String) -> void:
	hotkey_label.text = text


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
	var tex: Texture2D = null
	if data != null:
		# ItemData uses `icon`, but some legacy resources might still use `texture`.
		var icon = data.get("icon")
		if icon is Texture2D:
			tex = icon as Texture2D
		else:
			var legacy = data.get("texture")
			if legacy is Texture2D:
				tex = legacy as Texture2D
	texture_rect.texture = tex
	if count > 1:
		label.text = str(count)
	else:
		label.text = ""


func set_highlight(active: bool) -> void:
	highlight.visible = active
