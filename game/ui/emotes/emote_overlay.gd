class_name EmoteOverlay
extends CanvasLayer

const _BUBBLE_SCENE: PackedScene = preload("res://game/ui/emotes/emote_bubble.tscn")

@onready var _root: Control = get_node_or_null(NodePath("Root")) as Control

var _bubbles: Dictionary = {}
var _entries: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _root != null:
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_emote(
	component: EmoteComponent,
	channel: StringName,
	icon: Texture2D,
	text: String,
	duration: float,
	show_text: bool = true,
	show_panel: bool = true,
	scale_factor: float = 1.0
) -> void:
	if component == null or not is_instance_valid(component):
		return
	var key := _make_key(component, channel)
	var bubble := _bubbles.get(key) as EmoteBubble
	if bubble == null or not is_instance_valid(bubble):
		if _BUBBLE_SCENE == null:
			return
		bubble = _BUBBLE_SCENE.instantiate() as EmoteBubble
		if bubble == null:
			return
		_root.add_child(bubble)
		_bubbles[key] = bubble
		_entries[key] = {"component": component, "channel": channel}
		if bubble.has_signal("expired"):
			bubble.expired.connect(Callable(self, "_on_bubble_expired").bind(key))

	bubble.set_content(icon, text, duration, show_text, show_panel, scale_factor)
	_update_bubble_position(key, bubble, component)


func clear_emote(component: EmoteComponent, channel: StringName) -> void:
	var key := _make_key(component, channel)
	_remove_bubble(key)


func clear_all_for(component: EmoteComponent) -> void:
	if component == null:
		return
	var keys := _entries.keys()
	for k in keys:
		var entry: Variant = _entries.get(k)
		if entry is Dictionary and entry.get("component") == component:
			_remove_bubble(k)


func _process(_delta: float) -> void:
	if _entries.is_empty():
		return
	var keys := _entries.keys()
	for k in keys:
		var entry_any: Variant = _entries.get(k)
		if not (entry_any is Dictionary):
			_remove_bubble(k)
			continue
		var entry: Dictionary = entry_any
		var comp_any: Variant = entry.get("component")
		if comp_any == null or (comp_any is Object and not is_instance_valid(comp_any)):
			_remove_bubble(k)
			continue
		var comp: EmoteComponent = comp_any as EmoteComponent
		var bubble_any: Variant = _bubbles.get(k)
		if bubble_any == null or (bubble_any is Object and not is_instance_valid(bubble_any)):
			_remove_bubble(k)
			continue
		var bubble: EmoteBubble = bubble_any as EmoteBubble
		if bubble == null or not is_instance_valid(bubble):
			_remove_bubble(k)
			continue
		if comp == null or not is_instance_valid(comp):
			_remove_bubble(k)
			continue
		_update_bubble_position(k, bubble, comp)


func _update_bubble_position(_key: String, bubble: EmoteBubble, comp: EmoteComponent) -> void:
	if bubble == null or comp == null:
		return
	if comp.has_method("get_emote_world_pos"):
		var world_pos: Vector2 = comp.call("get_emote_world_pos")
		var screen_pos := _world_to_screen(world_pos)
		var anchor := bubble.get_anchor_offset()
		bubble.position = screen_pos - anchor


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return world_pos
	var rect := vp.get_visible_rect()
	var cam := vp.get_camera_2d()
	if cam == null:
		return rect.size * 0.5 + world_pos
	var zoom := cam.zoom
	var center := cam.global_position
	return ((world_pos - center) * zoom) + (rect.size * 0.5)


func _remove_bubble(key: String) -> void:
	var bubble_any: Variant = _bubbles.get(key)
	var bubble: EmoteBubble = bubble_any as EmoteBubble
	if bubble != null and is_instance_valid(bubble):
		bubble.queue_free()
	_bubbles.erase(key)
	_entries.erase(key)


func _make_key(component: EmoteComponent, channel: StringName) -> String:
	var owner_id := 0
	if component != null:
		var owner := component.get_entity()
		if owner != null:
			owner_id = int(owner.get_instance_id())
		else:
			owner_id = int(component.get_instance_id())
	return "%s:%s" % [str(owner_id), String(channel)]


func _on_bubble_expired(key: String) -> void:
	_remove_bubble(key)
