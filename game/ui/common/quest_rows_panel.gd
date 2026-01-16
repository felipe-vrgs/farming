@tool
class_name QuestRowsPanel
extends PanelContainer

## Reusable “rows in a styled panel” component for quest UI.
## Supports:
## - header rows ({header:true})
## - spacer rows ({spacer:true})
## - objective rows (QuestUiHelper.ObjectiveDisplay OR {text, icon, npc_id})
## - reward rows (QuestUiHelper.RewardDisplay)

@export_group("Style")
@export var panel_style: StyleBox = null:
	set(v):
		panel_style = v
		_apply_panel_style()

@export_group("Layout")
@export var row_separation: int = 4:
	set(v):
		row_separation = int(v)
		_apply_layout()
@export var spacer_height: int = 4

@export_group("Row sizing")
@export var font_size: int = 8:
	set(v):
		font_size = int(v)
@export var header_font_size: int = 8:
	set(v):
		header_font_size = int(v)
@export var left_icon_size: Vector2 = Vector2(18, 18):
	set(v):
		left_icon_size = v
@export var portrait_size: Vector2 = Vector2(28, 28):
	set(v):
		portrait_size = v
@export var header_modulate: Color = Color(1, 1, 1, 0.85)

@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_panel_style()
	_apply_layout()


func clear_rows() -> void:
	if _rows == null:
		return
	var children := _rows.get_children()
	for c in children:
		if c == null:
			continue
		if c.get_parent() == _rows:
			_rows.remove_child(c)
		c.free()


func set_rows(rows: Array) -> void:
	clear_rows()
	if _rows == null or rows == null:
		return
	for r in rows:
		_add_row(r)


func _add_row(r: Variant) -> void:
	if _rows == null:
		return

	if r is Dictionary:
		var d := r as Dictionary
		if bool(d.get("spacer", false)):
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, maxi(0, spacer_height))
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spacer.process_mode = Node.PROCESS_MODE_ALWAYS
			_rows.add_child(spacer)
			return

		if bool(d.get("header", false)):
			var hdr := Label.new()
			hdr.text = String(d.get("text", ""))
			hdr.add_theme_font_size_override(&"font_size", maxi(1, int(header_font_size)))
			hdr.modulate = header_modulate
			hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hdr.process_mode = Node.PROCESS_MODE_ALWAYS
			_rows.add_child(hdr)
			return

		var text := String(d.get("text", ""))
		var icon: Texture2D = d.get("icon") as Texture2D
		var npc_id := StringName(String(d.get("npc_id", "")))
		var npc_right_id := StringName(String(d.get("npc_right_id", "")))
		if not String(npc_id).is_empty() or not String(npc_right_id).is_empty():
			var o := QuestUiHelper.ObjectiveDisplay.new()
			o.text = text
			o.icon = icon
			o.npc_id = npc_id
			o.npc_right_id = npc_right_id
			_add_objective(o)
		else:
			_add_text_icon(text, icon)
		return

	if r is QuestUiHelper.RewardDisplay:
		_add_reward(r as QuestUiHelper.RewardDisplay)
		return

	if r is QuestUiHelper.ObjectiveDisplay:
		_add_objective(r as QuestUiHelper.ObjectiveDisplay)
		return

	# Fallback: show stringified value.
	_add_text_icon(String(r), null)


func _add_objective(o: QuestUiHelper.ObjectiveDisplay) -> void:
	var row := QuestDisplayRow.new()
	row.font_size = maxi(1, int(font_size))
	row.left_icon_size = left_icon_size
	row.portrait_size = portrait_size
	row.row_alignment = BoxContainer.ALIGNMENT_BEGIN
	row.setup_objective(o)
	_rows.add_child(row)


func _add_reward(d: QuestUiHelper.RewardDisplay) -> void:
	var row := QuestDisplayRow.new()
	row.font_size = maxi(1, int(font_size))
	row.left_icon_size = left_icon_size
	row.portrait_size = portrait_size
	row.row_alignment = BoxContainer.ALIGNMENT_BEGIN
	row.setup_reward(d)
	_rows.add_child(row)


func _add_text_icon(text: String, icon: Texture2D) -> void:
	var row := QuestDisplayRow.new()
	row.font_size = maxi(1, int(font_size))
	row.left_icon_size = left_icon_size
	row.portrait_size = portrait_size
	row.row_alignment = BoxContainer.ALIGNMENT_BEGIN
	row.setup_text_icon(text, icon)
	_rows.add_child(row)


func _apply_panel_style() -> void:
	if not is_inside_tree():
		return
	if panel_style == null:
		return
	add_theme_stylebox_override(&"panel", panel_style)


func _apply_layout() -> void:
	if _rows == null:
		return
	_rows.add_theme_constant_override(&"separation", maxi(0, int(row_separation)))
