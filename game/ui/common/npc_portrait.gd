@tool
class_name NpcPortrait
extends Control

@export var portrait_size: Vector2 = Vector2(24, 24):
	set(v):
		portrait_size = v
		custom_minimum_size = portrait_size
		_recenter()

@onready var _sprite: AnimatedSprite2D = %Sprite
var _pending_npc_id: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = portrait_size
	_recenter()
	# Apply any pending setup done before _ready().
	if not String(_pending_npc_id).is_empty():
		setup_from_npc_id(_pending_npc_id)


func setup_from_config(cfg: NpcConfig) -> void:
	var spr := _get_sprite()
	if spr == null:
		return
	if cfg == null:
		spr.sprite_frames = null
		return
	spr.process_mode = Node.PROCESS_MODE_ALWAYS
	spr.centered = true
	spr.sprite_frames = cfg.sprite_frames
	var anim := String(cfg.default_animation)
	if anim.is_empty():
		anim = "idle_front"
	if spr.sprite_frames != null and spr.sprite_frames.has_animation(anim):
		spr.play(anim)
	else:
		if spr.sprite_frames != null:
			var names := spr.sprite_frames.get_animation_names()
			if names.size() > 0:
				spr.play(String(names[0]))
	_recenter()


func setup_from_npc_id(npc_id: StringName) -> void:
	_pending_npc_id = npc_id
	var spr := _get_sprite()
	if spr != null:
		spr.process_mode = Node.PROCESS_MODE_ALWAYS
		NpcVisualsHelper.apply_to_sprite(spr, npc_id)
		_recenter()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recenter()


func _recenter() -> void:
	var spr := _get_sprite()
	if spr == null:
		return
	spr.position = size * 0.5


func _get_sprite() -> AnimatedSprite2D:
	# Allow setup calls before _ready() runs by resolving the node directly.
	if _sprite != null and is_instance_valid(_sprite):
		return _sprite
	var n := get_node_or_null(NodePath("Sprite"))
	if n is AnimatedSprite2D:
		_sprite = n as AnimatedSprite2D
	return _sprite
