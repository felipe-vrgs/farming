class_name CharacterVisual
extends Node2D

## Layered character renderer for modular sprites.
## Expects per-slot SpriteFrames with animations named: `<action>_<dir>`
## Where dir is one of: front/left/right/back.

@export var appearance: CharacterAppearance = null:
	set(v):
		appearance = v
		_apply_appearance()

## Folder containing exported PNG sheets (<action>/<slot>/<variant>.png)
@export var source_root: String = "res://assets/characters/base"
## Folder containing generated SpriteFrames (<slot>/<variant>.tres)
@export var generated_root: String = "res://assets/characters/generated"
## When true, build SpriteFrames in-memory from PNG sheets if generated .tres is missing.
@export var allow_runtime_build: bool = true

@onready var legs: AnimatedSprite2D = $Legs
@onready var torso: AnimatedSprite2D = $Torso
@onready var pants: AnimatedSprite2D = $Pants
@onready var shirt: AnimatedSprite2D = $Shirt
@onready var face: AnimatedSprite2D = $Face
@onready var hair: AnimatedSprite2D = $Hair
@onready var hands_top: AnimatedSprite2D = $HandsTopOverlay

const _DIRS: Array[StringName] = [&"front", &"left", &"right", &"back"]

static var _frames_cache: Dictionary = {}  # key: String -> SpriteFrames

# The single layer that is allowed to actually advance frames.
# All other layers are frame-synced to this "clock".
var _clock_layer: AnimatedSprite2D = null


func _ready() -> void:
	_apply_appearance()


func get_clock_sprite() -> AnimatedSprite2D:
	# External overlays (tool hands) can sync to this.
	# Prefer legs as clock (most consistently present across appearances).
	if _clock_layer != null and is_instance_valid(_clock_layer):
		return _clock_layer
	return legs if legs != null else torso


func _set_clock_layer_for(directed: StringName) -> void:
	# Prefer a visible layer that actually has this directed animation.
	# Legs are generally the most consistent across outfits, so keep them first.
	var candidates: Array[AnimatedSprite2D] = [legs, torso, pants, shirt, face, hair]
	for c in candidates:
		if c == null:
			continue
		if c.sprite_frames != null and c.sprite_frames.has_animation(directed):
			_clock_layer = c
			return
	# As a fallback, keep a stable layer even if animation isn't present.
	_clock_layer = legs if legs != null else torso


func play_directed(base_anim: StringName, facing_dir: Vector2) -> void:
	var dir_suffix := _direction_suffix(facing_dir)
	var directed := StringName(str(base_anim, "_", dir_suffix))
	_set_clock_layer_for(directed)

	# Base layers
	_play_or_fallback(legs, directed, dir_suffix)
	_play_or_fallback(torso, directed, dir_suffix)
	_play_or_fallback(pants, directed, dir_suffix)
	_play_or_fallback(shirt, directed, dir_suffix)
	_play_or_fallback(face, directed, dir_suffix)
	_play_or_fallback(hair, directed, dir_suffix)

	# Safety: if a previous state froze the clock (speed_scale=0),
	# ensure normal locomotion resumes when returning to movement/idle.
	if base_anim in [&"move", &"carry_move", &"idle", &"carry_idle"]:
		var clock := get_clock_sprite()
		if clock != null and float(clock.speed_scale) == 0.0:
			clock.speed_scale = 1.0
		# If something stopped the clock, resume it.
		if clock != null and not clock.is_playing():
			clock.play(clock.animation)

	# Optional overlay: hands above hair/face (carry).
	var wants_hands_top := base_anim == &"carry_idle" or base_anim == &"carry_move"
	if hands_top == null:
		return
	if not wants_hands_top:
		hands_top.visible = false
		hands_top.stop()
		return

	if hands_top.sprite_frames != null and hands_top.sprite_frames.has_animation(directed):
		hands_top.visible = true
		if hands_top.animation != directed:
			hands_top.play(directed)
	else:
		hands_top.visible = false
		hands_top.stop()


func play_resolved(directed: StringName) -> void:
	# Play a fully-resolved directed animation name like "move_front" or "carry_move_left".
	# Useful for NPCs/states that already resolve direction externally.
	var parts: Dictionary = _split_directed(directed)
	var base_anim: StringName = parts.get("base", &"idle") as StringName
	var dir_suffix: StringName = parts.get("dir", &"front") as StringName
	_set_clock_layer_for(directed)

	_play_or_fallback(legs, directed, dir_suffix)
	_play_or_fallback(torso, directed, dir_suffix)
	_play_or_fallback(pants, directed, dir_suffix)
	_play_or_fallback(shirt, directed, dir_suffix)
	_play_or_fallback(face, directed, dir_suffix)
	_play_or_fallback(hair, directed, dir_suffix)

	var wants_hands_top := base_anim == &"carry_idle" or base_anim == &"carry_move"
	if hands_top == null:
		return
	if not wants_hands_top:
		hands_top.visible = false
		hands_top.stop()
		return
	if hands_top.sprite_frames != null and hands_top.sprite_frames.has_animation(directed):
		hands_top.visible = true
		if hands_top.animation != directed:
			hands_top.play(directed)
	else:
		hands_top.visible = false
		hands_top.stop()

	# Same safety as play_directed: keep clock animating for idle/move loops.
	if base_anim in [&"move", &"carry_move", &"idle", &"carry_idle"]:
		var clock := get_clock_sprite()
		if clock != null and float(clock.speed_scale) == 0.0:
			clock.speed_scale = 1.0
		if clock != null and not clock.is_playing():
			clock.play(clock.animation)


func _process(_delta: float) -> void:
	_sync_layers()


func _sync_layers() -> void:
	var clock := get_clock_sprite()
	if clock == null:
		return

	# Only non-clock layers are synced (the clock is the one that advances).
	_sync_to_clock(legs, clock)
	_sync_to_clock(torso, clock)
	_sync_to_clock(pants, clock)
	_sync_to_clock(shirt, clock)
	_sync_to_clock(face, clock)
	_sync_to_clock(hair, clock)
	# hands_top must remain synced too when visible.
	_sync_to_clock(hands_top, clock)


func _sync_to_clock(layer: AnimatedSprite2D, clock: AnimatedSprite2D) -> void:
	if layer == null or clock == null:
		return
	if layer == clock:
		return
	if not layer.visible:
		return
	layer.frame = clock.frame
	layer.frame_progress = clock.frame_progress
	layer.speed_scale = clock.speed_scale


func _play_or_fallback(
	layer: AnimatedSprite2D, directed: StringName, dir_suffix: StringName
) -> void:
	if layer == null:
		return
	if layer.sprite_frames != null and layer.sprite_frames.has_animation(directed):
		layer.visible = true
		# If a previous state stopped the animation, ensure it resumes.
		if layer.animation != directed or not layer.is_playing():
			layer.play(directed)
		return

	# Fallback to idle in the same direction.
	var fallback := StringName(str("idle_", dir_suffix))
	if layer.sprite_frames != null and layer.sprite_frames.has_animation(fallback):
		layer.visible = true
		if layer.animation != fallback or not layer.is_playing():
			layer.play(fallback)
		return

	# Nothing to show.
	layer.visible = false
	layer.stop()


func _apply_appearance() -> void:
	if not is_inside_tree():
		return
	if appearance == null:
		return

	_assign_slot_frames(legs, "legs", appearance.legs_variant)
	_assign_slot_frames(torso, "torso", appearance.torso_variant)
	_assign_slot_frames(pants, "pants", appearance.pants_variant)
	_assign_slot_frames(shirt, "shirt", appearance.shirt_variant)
	_assign_slot_frames(face, "face", appearance.face_variant)
	_assign_slot_frames(hair, "hair", appearance.hair_variant)
	_assign_slot_frames(hands_top, "hands_top", appearance.hands_top_variant)


func _assign_slot_frames(node: AnimatedSprite2D, slot: String, variant: StringName) -> void:
	if node == null:
		return
	var v := String(variant).strip_edges()
	if v.is_empty():
		node.sprite_frames = null
		node.visible = false
		return

	var frames := _load_or_build_frames(slot, StringName(v))
	node.sprite_frames = frames
	# Do not force visibility here; play_directed decides.


func _load_or_build_frames(slot: String, variant: StringName) -> SpriteFrames:
	var key := "%s/%s" % [slot, String(variant)]
	if _frames_cache.has(key):
		return _frames_cache[key] as SpriteFrames

	# Prefer generated .tres.
	var res_path := "%s/%s/%s.tres" % [generated_root, slot, String(variant)]
	if ResourceLoader.exists(res_path):
		var r := load(res_path) as SpriteFrames
		_frames_cache[key] = r
		return r

	if not allow_runtime_build:
		_frames_cache[key] = null
		return null

	# Build from PNG sheets at runtime (in-memory).
	var r2 := _build_frames_from_png_sheets(slot, variant)
	_frames_cache[key] = r2
	return r2


func _build_frames_from_png_sheets(slot: String, variant: StringName) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var cell := Vector2i(32, 32)
	var order_dirs: Array[StringName] = _DIRS

	var actions := [&"idle", &"move", &"carry_idle", &"carry_move", &"use", &"swing"]
	for base_anim in actions:
		var png_path := "%s/%s/%s/%s.png" % [source_root, String(base_anim), slot, String(variant)]
		if not ResourceLoader.exists(png_path):
			continue
		var tex := load(png_path) as Texture2D
		if tex == null:
			continue

		for row_i in range(order_dirs.size()):
			var dir := order_dirs[row_i]
			var anim_name := StringName(str(base_anim, "_", dir))
			if not frames.has_animation(anim_name):
				frames.add_animation(anim_name)
				frames.set_animation_speed(anim_name, 6.0)
				frames.set_animation_loop(anim_name, true)

			for col_i in range(4):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2i(col_i * cell.x, row_i * cell.y, cell.x, cell.y)
				frames.add_frame(anim_name, at)

	# Tool-use/carry typically should not loop; adjust common non-looping.
	for base_anim2 in [&"use", &"swing"]:
		for dir2 in order_dirs:
			var n := StringName(str(base_anim2, "_", dir2))
			if frames.has_animation(n):
				frames.set_animation_loop(n, false)
				frames.set_animation_speed(n, 6.0)
	for base_anim3 in [&"carry_idle", &"carry_move", &"idle", &"move"]:
		for dir3 in order_dirs:
			var n2 := StringName(str(base_anim3, "_", dir3))
			if frames.has_animation(n2):
				frames.set_animation_loop(n2, true)
				frames.set_animation_speed(
					n2, 6.0 if base_anim3 in [&"move", &"carry_move"] else 2.0
				)

	return frames


func _direction_suffix(dir: Vector2) -> StringName:
	if abs(dir.x) >= abs(dir.y):
		return &"right" if dir.x > 0.0 else &"left"
	return &"front" if dir.y > 0.0 else &"back"


func _split_directed(directed: StringName) -> Dictionary:
	# Returns: { base: StringName, dir: StringName }
	var s := String(directed)
	for d in ["front", "left", "right", "back"]:
		var suffix := "_%s" % d
		if s.ends_with(suffix):
			return {
				"base": StringName(s.substr(0, s.length() - suffix.length())), "dir": StringName(d)
			}
	# Fallback: treat as idle_front for safety.
	return {"base": &"idle", "dir": &"front"}
