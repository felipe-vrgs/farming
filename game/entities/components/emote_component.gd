class_name EmoteComponent
extends Node

## Lightweight component that exposes emote/prompt UI above an entity.

@export var anchor_path: NodePath = NodePath("Markers/Chest")
@export var offset: Vector2 = Vector2(0.0, -28.0)


func _enter_tree() -> void:
	add_to_group(Groups.EMOTE_COMPONENTS)


func get_entity() -> Node:
	# Mirror InteractableComponent.get_entity() convention so composition works
	# regardless of whether this component is placed directly under the entity
	# or under an entity's `Components/` container.
	var p := get_parent()
	if p == null:
		return null
	if StringName(p.name) == &"Components":
		return p.get_parent()
	return p


func get_emote_world_pos() -> Vector2:
	var anchor := _resolve_anchor_node()
	if anchor is Node2D:
		return (anchor as Node2D).global_position + offset
	var e := get_entity()
	if e is Node2D:
		return (e as Node2D).global_position + offset
	return Vector2.ZERO


func show_emote(
	channel: StringName,
	icon: Texture2D,
	text: String = "",
	duration: float = 1.0,
	show_text: bool = true,
	show_panel: bool = true,
	scale_factor: float = 1.0
) -> void:
	if String(channel).is_empty():
		return
	var overlay := _get_overlay()
	if overlay != null and overlay.has_method("show_emote"):
		overlay.call(
			"show_emote", self, channel, icon, text, duration, show_text, show_panel, scale_factor
		)


func show_emote_icon_path(
	channel: StringName,
	icon_path: String,
	text: String = "",
	duration: float = 1.0,
	show_text: bool = true,
	show_panel: bool = true,
	scale_factor: float = 1.0
) -> void:
	var icon: Texture2D = null
	var p := String(icon_path).strip_edges()
	if not p.is_empty() and ResourceLoader.exists(p):
		var res := ResourceLoader.load(p)
		if res is Texture2D:
			icon = res
	show_emote(channel, icon, text, duration, show_text, show_panel, scale_factor)


func clear(channel: StringName) -> void:
	if String(channel).is_empty():
		return
	var overlay := _get_overlay()
	if overlay != null and overlay.has_method("clear_emote"):
		overlay.call("clear_emote", self, channel)


func clear_all() -> void:
	var overlay := _get_overlay()
	if overlay != null and overlay.has_method("clear_all_for"):
		overlay.call("clear_all_for", self)


func _resolve_anchor_node() -> Node2D:
	var e := get_entity()
	if e == null:
		return null
	var candidate := e.get_node_or_null(anchor_path)
	if candidate is Node2D:
		return candidate as Node2D
	# Fallbacks for common marker conventions.
	var chest := e.get_node_or_null(NodePath("Markers/Chest"))
	if chest is Node2D:
		return chest as Node2D
	var feet := e.get_node_or_null(NodePath("Markers/Feet"))
	if feet is Node2D:
		return feet as Node2D
	if e is Node2D:
		return e as Node2D
	return null


func _get_overlay() -> Node:
	if UIManager == null:
		return null
	if UIManager.has_method("get_screen_node") and "ScreenName" in UIManager:
		return UIManager.get_screen_node(UIManager.ScreenName.EMOTE_OVERLAY)
	return null
