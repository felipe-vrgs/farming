class_name NpcVisualsHelper
extends RefCounted

## Shared helper to resolve NPC visuals consistently across UI.
## - Loads `NpcConfig` by npc_id
## - Applies `sprite_frames` + default animation to an AnimatedSprite2D
## - Can return a preview icon (first frame of default animation)

const _NPC_CONFIGS_DIR := "res://game/entities/npc/configs"

static var _config_cache: Dictionary = {}  # npc_id:StringName -> NpcConfig (or null)
static var _icon_cache: Dictionary = {}  # npc_id:StringName -> Texture2D (or null)


static func config_path(npc_id: StringName) -> String:
	return "%s/%s.tres" % [_NPC_CONFIGS_DIR, String(npc_id)]


static func load_config(npc_id: StringName) -> NpcConfig:
	if String(npc_id).is_empty():
		return null
	if _config_cache.has(npc_id):
		return _config_cache[npc_id] as NpcConfig

	var p := config_path(npc_id)
	var cfg: NpcConfig = null
	if ResourceLoader.exists(p):
		var res := load(p)
		cfg = res as NpcConfig
	_config_cache[npc_id] = cfg
	return cfg


static func apply_to_sprite(sprite: AnimatedSprite2D, npc_id: StringName) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var cfg := load_config(npc_id)
	if cfg == null:
		sprite.sprite_frames = null
		return
	sprite.sprite_frames = cfg.sprite_frames
	var anim := String(cfg.default_animation)
	if anim.is_empty():
		anim = "idle_front"
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		if sprite.sprite_frames != null:
			var names := sprite.sprite_frames.get_animation_names()
			if names.size() > 0:
				sprite.play(String(names[0]))


static func resolve_icon(npc_id: StringName) -> Texture2D:
	# Best-effort: use the NPC's default animation first frame as an icon.
	if String(npc_id).is_empty():
		return null
	if _icon_cache.has(npc_id):
		return _icon_cache[npc_id] as Texture2D

	var icon: Texture2D = null
	var cfg := load_config(npc_id)
	if cfg != null and cfg.sprite_frames != null and is_instance_valid(cfg.sprite_frames):
		var anim := String(cfg.default_animation)
		if anim.is_empty():
			anim = "idle_front"
		if cfg.sprite_frames.has_animation(anim) and cfg.sprite_frames.get_frame_count(anim) > 0:
			icon = cfg.sprite_frames.get_frame_texture(anim, 0)

	_icon_cache[npc_id] = icon
	return icon


static func clear_caches() -> void:
	_config_cache.clear()
	_icon_cache.clear()
