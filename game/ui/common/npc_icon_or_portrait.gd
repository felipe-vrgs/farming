@tool
class_name NpcIconOrPortrait
extends Control

## Small UI helper that can render either:
## - an animated NPC portrait (when npc_id is set), or
## - a static icon texture (when icon is set).
##
## Goal: centralize the branching logic so quest popup/menu render consistently.

const _PORTRAIT_SCENE: PackedScene = preload("res://game/ui/common/npc_portrait.tscn")

@export var icon_size: Vector2 = Vector2(24, 24):
	set(v):
		icon_size = v
		custom_minimum_size = icon_size
		_apply_layout()

var _prefer_portrait: bool = true
var _npc_id: StringName = &""
var _icon: Texture2D = null

var _portrait: Control = null
var _icon_rect: TextureRect = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = icon_size
	_ensure_children()
	_apply_layout()
	_apply_state()


func setup(npc_id: StringName, icon: Texture2D, prefer_portrait: bool = true) -> void:
	_prefer_portrait = bool(prefer_portrait)
	_npc_id = npc_id
	_icon = icon
	_apply_state()


func set_npc_id(npc_id: StringName, prefer_portrait: bool = true) -> void:
	_prefer_portrait = bool(prefer_portrait)
	_npc_id = npc_id
	_apply_state()


func set_icon(icon: Texture2D) -> void:
	_icon = icon
	_apply_state()


func clear() -> void:
	_npc_id = &""
	_icon = null
	_apply_state()


func _ensure_children() -> void:
	if _icon_rect == null or not is_instance_valid(_icon_rect):
		_icon_rect = TextureRect.new()
		_icon_rect.name = "Icon"
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_icon_rect)

	if _portrait == null or not is_instance_valid(_portrait):
		_portrait = null
		if _PORTRAIT_SCENE != null:
			_portrait = _PORTRAIT_SCENE.instantiate() as Control
		if _portrait == null:
			_portrait = Control.new()
		_portrait.name = "Portrait"
		_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_portrait)


func _apply_layout() -> void:
	if _icon_rect != null and is_instance_valid(_icon_rect):
		_icon_rect.custom_minimum_size = icon_size
		_icon_rect.size = icon_size
		_icon_rect.position = Vector2.ZERO

	if _portrait != null and is_instance_valid(_portrait):
		if "portrait_size" in _portrait:
			_portrait.set("portrait_size", icon_size)
		else:
			_portrait.custom_minimum_size = icon_size
		_portrait.size = icon_size
		_portrait.position = Vector2.ZERO


func _apply_state() -> void:
	# Allow setup calls before _ready() by deferring until nodes exist.
	if not is_inside_tree():
		return
	_ensure_children()
	_apply_layout()

	var has_npc := not String(_npc_id).is_empty()
	var should_show_portrait := _prefer_portrait and has_npc

	if _icon_rect != null and is_instance_valid(_icon_rect):
		_icon_rect.texture = _icon
		_icon_rect.visible = not should_show_portrait and _icon != null

	if _portrait != null and is_instance_valid(_portrait):
		_portrait.visible = should_show_portrait
		if should_show_portrait and _portrait.has_method("setup_from_npc_id"):
			_portrait.call("setup_from_npc_id", _npc_id)
