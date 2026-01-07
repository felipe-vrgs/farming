@tool
class_name HotbarSlot
extends PanelContainer

var tool_data: ToolData
var item_data: ItemData

@export var normal_panel_style: StyleBox = null
@export var selected_panel_style: StyleBox = null

@export_group("Preview (Editor)")
@export var preview_enabled: bool = false:
	set(v):
		preview_enabled = v
		_apply_preview()
@export var preview_hotkey: String = "1":
	set(v):
		preview_hotkey = v
		_apply_preview()
@export var preview_item: ItemData = null:
	set(v):
		preview_item = v
		_apply_preview()
@export var preview_tool: ToolData = null:
	set(v):
		preview_tool = v
		_apply_preview()
@export var preview_count: int = 1:
	set(v):
		preview_count = v
		_apply_preview()
@export var preview_selected: bool = false:
	set(v):
		preview_selected = v
		_apply_preview()

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect
@onready var count_label: Label = $CountLabel
@onready var hotkey_label: Label = $HotkeyLabel
@onready var highlight: ReferenceRect = $ReferenceRect

var _preview_apply_queued: bool = false


func _ready() -> void:
	if highlight != null:
		highlight.visible = false
	# Default panel style.
	if normal_panel_style != null:
		add_theme_stylebox_override(&"panel", normal_panel_style)
	if count_label != null:
		count_label.text = ""
	if hotkey_label != null:
		hotkey_label.text = ""
	_apply_preview()


func set_hotkey(text: String) -> void:
	if hotkey_label == null:
		return
	hotkey_label.text = text


func set_tool(data: ToolData) -> void:
	tool_data = data
	item_data = null
	if texture_rect != null:
		var tex: Texture2D = null
		if data != null:
			# ToolData inherits ItemData; use icon.
			if data.icon is Texture2D:
				tex = data.icon
		else:
			tex = null
		texture_rect.texture = tex
	if count_label != null:
		count_label.text = ""


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
	if texture_rect != null:
		texture_rect.texture = tex
	if count_label != null:
		if count > 1:
			count_label.text = str(count)
		else:
			count_label.text = ""


func set_highlight(active: bool) -> void:
	# Prefer swapping the panel border color (pixel-art friendly).
	if normal_panel_style != null and selected_panel_style != null:
		add_theme_stylebox_override(
			&"panel", selected_panel_style if active else normal_panel_style
		)
		if highlight != null:
			highlight.visible = false
		return

	# Fallback (legacy): show an overlay border.
	if highlight != null:
		highlight.visible = active


func _apply_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if not preview_enabled:
		return
	# Tool scripts can have export setters called before _ready() (onready vars null).
	if not is_node_ready():
		if not _preview_apply_queued:
			_preview_apply_queued = true
			call_deferred("_apply_preview_deferred")
		return
	# In-editor preview: allow scene testing without runtime bindings.
	set_hotkey(preview_hotkey)
	if preview_tool != null:
		set_tool(preview_tool)
	elif preview_item != null:
		set_item(preview_item, maxi(1, preview_count))
	else:
		set_item(null, 0)
	set_highlight(preview_selected)


func _apply_preview_deferred() -> void:
	_preview_apply_queued = false
	_apply_preview()
