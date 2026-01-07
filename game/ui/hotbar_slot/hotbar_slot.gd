@tool
class_name HotbarSlot
extends PanelContainer

signal clicked(index: int)
signal activated(index: int)
signal dropped(src_index: int, dest_index: int)

var inventory: InventoryData = null
var slot_index: int = -1

var tool_data: ToolData
var item_data: ItemData

@export var editable: bool = true
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
var _is_selected: bool = false
var _is_moving: bool = false
var _focused_panel_style: StyleBox = null
var _moving_panel_style: StyleBox = null


func setup(new_inventory: InventoryData, new_slot_index: int, enable_focus: bool = false) -> void:
	inventory = new_inventory
	slot_index = new_slot_index
	focus_mode = Control.FOCUS_ALL if enable_focus else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)

	if highlight != null:
		highlight.visible = false
	# Default panel style.
	if normal_panel_style != null:
		add_theme_stylebox_override(&"panel", normal_panel_style)
	if count_label != null:
		count_label.text = ""
	if hotkey_label != null:
		hotkey_label.text = ""
	_ensure_generated_styles()
	_apply_visual_state()
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
	_is_selected = active
	_apply_visual_state()


func set_moving(active: bool) -> void:
	_is_moving = active
	_apply_visual_state()


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


func _gui_input(event: InputEvent) -> void:
	if event == null:
		return

	# Click selects/activates the slot for parent UI.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if focus_mode != Control.FOCUS_NONE:
				grab_focus()
			if slot_index >= 0:
				clicked.emit(slot_index)
			accept_event()
			return

	# Keyboard "accept" triggers parent swap/equip logic.
	if event.is_action_pressed(&"ui_accept", false, true):
		if slot_index >= 0:
			activated.emit(slot_index)
		accept_event()
		return


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not editable:
		return null
	if inventory == null or slot_index < 0:
		return null
	# Only drag if there's something to drag.
	if tool_data == null and item_data == null:
		return null

	var payload := {
		"inventory": inventory,
		"index": slot_index,
	}

	# Drag preview: show the icon.
	var preview := TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if texture_rect != null:
		preview.texture = texture_rect.texture
	preview.custom_minimum_size = size
	set_drag_preview(preview)

	return payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not editable or inventory == null or slot_index < 0:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d := data as Dictionary
	if not d.has("inventory") or not d.has("index"):
		return false
	if d["inventory"] != inventory:
		return false
	var src := int(d["index"])
	if src < 0 or src >= inventory.slots.size():
		return false
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var d := data as Dictionary
	var src := int(d["index"])

	dropped.emit(src, slot_index)

	if inventory != null:
		inventory.swap_slots(src, slot_index)


func _on_focus_changed() -> void:
	_apply_visual_state()


func _ensure_generated_styles() -> void:
	if _focused_panel_style == null and normal_panel_style is StyleBoxFlat:
		var focused := (normal_panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		# Soft cyan focus border.
		focused.border_color = Color(0.60, 0.90, 1.00, 1.00)
		_focused_panel_style = focused

	if _moving_panel_style == null and normal_panel_style is StyleBoxFlat:
		var moving := (normal_panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		# Orange "picked up" border.
		moving.border_color = Color(1.00, 0.70, 0.20, 1.00)
		_moving_panel_style = moving


func _apply_visual_state() -> void:
	_ensure_generated_styles()

	# Prefer swapping the panel border color (pixel-art friendly).
	if normal_panel_style != null and selected_panel_style != null:
		var style: StyleBox = normal_panel_style
		if _is_moving and _moving_panel_style != null:
			style = _moving_panel_style
		# Focus and selection should look the same (yellow) for keyboard navigation.
		elif _is_selected or has_focus():
			style = selected_panel_style

		add_theme_stylebox_override(&"panel", style)
		if highlight != null:
			highlight.visible = false
	else:
		# Fallback: show overlay border (selection/focus/moving).
		if highlight != null:
			highlight.visible = _is_selected or has_focus() or _is_moving

	# Dim the "picked up" slot content slightly.
	if texture_rect != null:
		texture_rect.modulate = Color(1, 1, 1, 0.55) if _is_moving else Color(1, 1, 1, 1)
