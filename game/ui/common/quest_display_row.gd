@tool
class_name QuestDisplayRow
extends HBoxContainer

## Reusable row renderer for quest UI entries (objectives or rewards).
## - Left side: NPC portrait (preferred) or static icon
## - Center: text label
## - Optional right-side NPC portrait (used for relationship rewards: heart + text + npc)

@export var left_icon_size: Vector2 = Vector2(16, 16):
	set(v):
		left_icon_size = v
		_apply_layout()

@export var portrait_size: Vector2 = Vector2(24, 24):
	set(v):
		portrait_size = v
		_apply_layout()

@export var label_settings: LabelSettings = null:
	set(v):
		label_settings = v
		_apply_layout()

@export var font_size: int = 0:
	set(v):
		font_size = int(v)
		_apply_layout()

@export var row_alignment: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_CENTER:
	set(v):
		row_alignment = v
		_apply_row_alignment()

var _left: NpcIconOrPortrait = null
var _label: Label = null
var _spacer: Control = null
var _right: NpcIconOrPortrait = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	_apply_row_alignment()
	_ensure_nodes()
	_spacer.visible = false
	_apply_layout()


func setup_objective(d: QuestUiHelper.ObjectiveDisplay) -> void:
	_ensure_nodes()
	if d == null:
		clear()
		return
	_left.setup(d.npc_id, d.icon, true)
	_label.text = String(d.text).strip_edges()
	_spacer.visible = false
	_right.visible = false


func setup_reward(d: QuestUiHelper.RewardDisplay) -> void:
	_ensure_nodes()
	if d == null:
		clear()
		return
	var is_relationship := d.kind == &"relationship"
	_left.setup(&"", d.icon, false)
	_label.text = String(d.text).strip_edges()
	_right.visible = is_relationship and not String(d.npc_id).is_empty()
	_spacer.visible = _right.visible
	if _right.visible:
		_right.setup(d.npc_id, null, true)


func setup_text_icon(text: String, icon: Texture2D = null) -> void:
	_ensure_nodes()
	_left.setup(&"", icon, false)
	_label.text = String(text).strip_edges()
	_spacer.visible = false
	_right.visible = false


func clear() -> void:
	_ensure_nodes()
	_left.clear()
	_label.text = ""
	_spacer.visible = false
	_right.visible = false


func _apply_layout() -> void:
	_ensure_nodes()
	if _left != null and is_instance_valid(_left):
		_left.icon_size = left_icon_size
	if _right != null and is_instance_valid(_right):
		_right.icon_size = portrait_size
	if _label != null and is_instance_valid(_label):
		if label_settings != null:
			_label.label_settings = label_settings
		if font_size > 0:
			_label.add_theme_font_size_override(&"font_size", font_size)


func _apply_row_alignment() -> void:
	alignment = row_alignment


func _ensure_nodes() -> void:
	if _left == null or not is_instance_valid(_left):
		_left = _ensure_left()
	if _label == null or not is_instance_valid(_label):
		_label = _ensure_label()
	if _spacer == null or not is_instance_valid(_spacer):
		_spacer = _ensure_spacer()
	if _right == null or not is_instance_valid(_right):
		_right = _ensure_right()


func _ensure_left() -> NpcIconOrPortrait:
	var n := get_node_or_null(NodePath("Left")) as NpcIconOrPortrait
	if n != null and is_instance_valid(n):
		return n
	n = NpcIconOrPortrait.new()
	n.name = "Left"
	n.icon_size = left_icon_size
	add_child(n)
	return n


func _ensure_label() -> Label:
	var n := get_node_or_null(NodePath("Text")) as Label
	if n != null and is_instance_valid(n):
		return n
	n = Label.new()
	n.name = "Text"
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(n)
	return n


func _ensure_spacer() -> Control:
	var n := get_node_or_null(NodePath("Spacer")) as Control
	if n != null and is_instance_valid(n):
		return n
	n = Control.new()
	n.name = "Spacer"
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(n)
	return n


func _ensure_right() -> NpcIconOrPortrait:
	var n := get_node_or_null(NodePath("Right")) as NpcIconOrPortrait
	if n != null and is_instance_valid(n):
		return n
	n = NpcIconOrPortrait.new()
	n.name = "Right"
	n.icon_size = portrait_size
	n.visible = false
	add_child(n)
	return n
