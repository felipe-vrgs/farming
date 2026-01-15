@tool
class_name CharacterVisual
extends Node2D

## Layered character renderer for modular sprites.
## Expects per-slot SpriteFrames with animations named: `<action>_<dir>`
## Where dir is one of: front/left/right/back.

@export_group("Editor Preview")
@export var editor_preview_enabled: bool = false:
	set(v):
		editor_preview_enabled = v
		_update_editor_preview()
## Directed animation name like "idle_front", "move_left", "carry_idle_back", "use_front", ...
@export var editor_preview_directed_anim: StringName = &"idle_front":
	set(v):
		editor_preview_directed_anim = v
		_update_editor_preview()

@export var appearance: CharacterAppearance = null:
	set(v):
		if appearance == v:
			return
		_disconnect_appearance_signals()
		appearance = v
		_connect_appearance_signals()
		if Engine.is_editor_hint():
			_update_editor_preview()
		else:
			_apply_appearance()

## Folder containing exported PNG sheets (<action>/<slot>/<variant>.png)
@export var source_root: String = "res://assets/characters/base"
## Folder containing generated SpriteFrames (<slot>/<variant>.tres)
@export var generated_root: String = "res://assets/characters/generated"
## When true, build SpriteFrames in-memory from PNG sheets if generated .tres is missing.
@export var allow_runtime_build: bool = true
## Palette swap toggle.
@export var enable_palette_swap: bool = true

@onready var legs: AnimatedSprite2D = $Legs
@onready var shoes: AnimatedSprite2D = $Shoes
@onready var torso: AnimatedSprite2D = $Torso
@onready var pants: AnimatedSprite2D = $Pants
@onready var shirt: AnimatedSprite2D = $Shirt
@onready var hands: AnimatedSprite2D = $Hands
@onready var face: AnimatedSprite2D = $Face
@onready var hair: AnimatedSprite2D = $Hair

const _DIRS: Array[StringName] = [&"front", &"left", &"right", &"back"]

static var _frames_cache: Dictionary = {}  # key: String -> SpriteFrames

# The single layer that is allowed to actually advance frames.
# All other layers are frame-synced to this "clock".
var _clock_layer: AnimatedSprite2D = null

# Instance-specific palette materials (do not share across characters).
var _skin_eyes_material: ShaderMaterial = null
var _hair_material: ShaderMaterial = null

const _SKIN_EYES_SHADER := preload(
	"res://game/entities/character/shaders/palette_swap_skin_eyes_v2.gdshader"
)
const _HAIR_SHADER := preload("res://game/entities/character/shaders/palette_swap_hair_v2.gdshader")

var _pending_freeze: bool = false
var _pending_freeze_target_frame: int = 0
var _pending_freeze_anim: StringName = &""

# Track the last high-level request so we can smooth transitions.
var _last_requested_base: StringName = &""
var _last_resolved_directed: StringName = &""

const _EDITOR_PREVIEW_FALLBACK_ANIM: StringName = &"idle_front"


func _ready() -> void:
	_connect_appearance_signals()
	# Pixel art: avoid filtering/atlas bleed so palette swap matches exact key colors.
	for layer in [legs, shoes, torso, pants, shirt, hands, face, hair]:
		if layer == null:
			continue
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if Engine.is_editor_hint():
		_update_editor_preview()
	else:
		_apply_appearance()


func _exit_tree() -> void:
	_disconnect_appearance_signals()


func get_clock_sprite() -> AnimatedSprite2D:
	# External overlays (tool hands) can sync to this.
	# Prefer legs as clock (most consistently present across appearances).
	if _clock_layer != null and is_instance_valid(_clock_layer):
		return _clock_layer
	return legs if legs != null else torso


func _enforce_disabled_slots_from_appearance() -> void:
	# Hard guarantee: if a clothing slot variant is empty, it can never render.
	# This prevents rare one-frame flickers when a layer still has stale SpriteFrames.
	if appearance == null:
		return
	_disable_layer_if_variant_empty(shirt, appearance.shirt_variant)
	_disable_layer_if_variant_empty(pants, appearance.pants_variant)
	_disable_layer_if_variant_empty(shoes, appearance.shoes_variant)


func _disable_layer_if_variant_empty(layer: AnimatedSprite2D, variant: StringName) -> void:
	if layer == null:
		return
	if not String(variant).strip_edges().is_empty():
		return
	layer.sprite_frames = null
	layer.visible = false
	layer.stop()


func _set_clock_layer_for(directed: StringName) -> void:
	# Prefer a visible layer that actually has this directed animation.
	# Legs are generally the most consistent across outfits, so keep them first.
	var candidates: Array[AnimatedSprite2D] = [legs, shoes, torso, pants, shirt, hands, face, hair]
	for c in candidates:
		if c == null:
			continue
		if not c.visible:
			continue
		if c.sprite_frames != null and c.sprite_frames.has_animation(directed):
			_clock_layer = c
			return
	# As a fallback, keep a stable layer even if animation isn't present.
	_clock_layer = legs if legs != null else torso


func play_directed(base_anim: StringName, facing_dir: Vector2) -> void:
	var prev_base := _last_requested_base
	var prev_resolved := _last_resolved_directed
	var dir_suffix := _direction_suffix(facing_dir)
	var directed := _resolve_directed(StringName(str(base_anim, "_", dir_suffix)))
	_enforce_disabled_slots_from_appearance()
	_set_clock_layer_for(directed)

	# Base layers
	_play_or_fallback(legs, directed, dir_suffix)
	_play_or_fallback(shoes, directed, dir_suffix)
	_play_or_fallback(torso, directed, dir_suffix)
	_play_or_fallback(pants, directed, dir_suffix)
	_play_or_fallback(shirt, directed, dir_suffix)
	_play_or_fallback(hands, directed, dir_suffix)
	_play_or_fallback(face, directed, dir_suffix)
	_play_or_fallback(hair, directed, dir_suffix)

	_apply_hold_policy(base_anim, prev_base, prev_resolved)
	_last_requested_base = base_anim
	_last_resolved_directed = directed


func play_resolved(directed: StringName) -> void:
	# Play a fully-resolved directed animation name like "move_front" or "carry_move_left".
	# Useful for NPCs/states that already resolve direction externally.
	var parts: Dictionary = _split_directed(directed)
	var base_anim: StringName = parts.get("base", &"idle") as StringName
	var dir_suffix: StringName = parts.get("dir", &"front") as StringName
	var resolved := _resolve_directed(directed)
	var prev_base := _last_requested_base
	var prev_resolved := _last_resolved_directed
	_enforce_disabled_slots_from_appearance()
	_set_clock_layer_for(resolved)

	_play_or_fallback(legs, resolved, dir_suffix)
	_play_or_fallback(shoes, resolved, dir_suffix)
	_play_or_fallback(torso, resolved, dir_suffix)
	_play_or_fallback(pants, resolved, dir_suffix)
	_play_or_fallback(shirt, resolved, dir_suffix)
	_play_or_fallback(hands, resolved, dir_suffix)
	_play_or_fallback(face, resolved, dir_suffix)
	_play_or_fallback(hair, resolved, dir_suffix)

	_apply_hold_policy(base_anim, prev_base, prev_resolved)
	_last_requested_base = base_anim
	_last_resolved_directed = resolved


func _process(_delta: float) -> void:
	_sync_layers()
	_update_pending_freeze()


func _sync_layers() -> void:
	var clock := get_clock_sprite()
	if clock == null:
		return

	# Only non-clock layers are synced (the clock is the one that advances).
	_sync_to_clock(legs, clock)
	_sync_to_clock(shoes, clock)
	_sync_to_clock(torso, clock)
	_sync_to_clock(pants, clock)
	_sync_to_clock(shirt, clock)
	_sync_to_clock(hands, clock)
	_sync_to_clock(face, clock)
	_sync_to_clock(hair, clock)


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

	# Fallback to move in the same direction (generated sheets always include move_*).
	var fallback := StringName(str("move_", dir_suffix))
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
	_assign_slot_frames(shoes, "shoes", appearance.shoes_variant)
	_assign_slot_frames(torso, "torso", appearance.torso_variant)
	_assign_slot_frames(pants, "pants", appearance.pants_variant)
	_assign_slot_frames(shirt, "shirt", appearance.shirt_variant)
	_assign_slot_frames(hands, "hands", appearance.hands_variant)
	_assign_slot_frames(face, "face", appearance.face_variant)
	_assign_slot_frames(hair, "hair", appearance.hair_variant)
	_apply_palette()
	_enforce_disabled_slots_from_appearance()


func _on_appearance_resource_changed() -> void:
	# Called when the Resource changes in the inspector (including in the editor).
	if Engine.is_editor_hint():
		_update_editor_preview()
	else:
		_apply_appearance()


func _connect_appearance_signals() -> void:
	if appearance == null:
		return
	if not appearance.changed.is_connected(_on_appearance_resource_changed):
		appearance.changed.connect(_on_appearance_resource_changed)


func _disconnect_appearance_signals() -> void:
	if appearance == null:
		return
	if appearance.changed.is_connected(_on_appearance_resource_changed):
		appearance.changed.disconnect(_on_appearance_resource_changed)


func _update_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return

	# Only show something in the editor when explicitly enabled.
	var enabled := (
		editor_preview_enabled or (appearance != null and appearance.editor_preview_enabled)
	)
	if not enabled:
		_hide_all_layers_editor_only()
		return

	# Ensure frames/materials exist before playing.
	_apply_appearance()

	# Ensure processing runs so layer sync + freeze logic works while editing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

	var anim := _EDITOR_PREVIEW_FALLBACK_ANIM
	if not String(editor_preview_directed_anim).strip_edges().is_empty():
		anim = editor_preview_directed_anim
	elif appearance != null:
		anim = appearance.editor_preview_directed_anim
	if String(anim).strip_edges().is_empty():
		anim = _EDITOR_PREVIEW_FALLBACK_ANIM

	play_resolved(anim)


func _hide_all_layers_editor_only() -> void:
	if not Engine.is_editor_hint():
		return
	set_process(false)
	for layer in [legs, shoes, torso, pants, shirt, hands, face, hair]:
		if layer == null:
			continue
		layer.visible = false
		layer.stop()


func _apply_palette() -> void:
	# Apply skin/eye palette swap to the relevant layers.
	if not is_inside_tree():
		return
	if appearance == null:
		return
	if not enable_palette_swap:
		for layer in [legs, shoes, torso, pants, shirt, hands, face, hair]:
			if layer != null:
				layer.material = null
		return

	if _skin_eyes_material == null:
		_skin_eyes_material = ShaderMaterial.new()
		_skin_eyes_material.shader = _SKIN_EYES_SHADER
	if _hair_material == null:
		_hair_material = ShaderMaterial.new()
		_hair_material.shader = _HAIR_SHADER

	# Skin + eyes uniforms.
	_skin_eyes_material.set_shader_parameter("skin_out_0", appearance.skin_color)
	_skin_eyes_material.set_shader_parameter("skin_out_1", appearance.skin_color_secondary)
	_skin_eyes_material.set_shader_parameter("eye_out", appearance.eye_color)

	# Hair uniforms (derive 4 tones from base).
	var hair_tones := CharacterPalettes.derive_hair_tones(appearance.hair_color)
	if hair_tones.size() >= 4:
		_hair_material.set_shader_parameter("hair_out_0", hair_tones[0])
		_hair_material.set_shader_parameter("hair_out_1", hair_tones[1])
		_hair_material.set_shader_parameter("hair_out_2", hair_tones[2])
		_hair_material.set_shader_parameter("hair_out_3", hair_tones[3])

	# Apply materials.
	for layer in [legs, torso, face, hands]:
		if layer != null:
			layer.material = _skin_eyes_material
	if hair != null:
		hair.material = _hair_material


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
		# If newer authoring added sheets (e.g. `use_*`) but the generated `.tres` wasn't rebuilt,
		# merge missing animations from PNGs at runtime so gameplay can still play them.
		if r != null and allow_runtime_build:
			_merge_action_from_png_if_missing(r, &"use", slot, variant)
		_frames_cache[key] = r
		return r

	if not allow_runtime_build:
		_frames_cache[key] = null
		return null

	# Build from PNG sheets at runtime (in-memory).
	var r2 := _build_frames_from_png_sheets(slot, variant)
	_frames_cache[key] = r2
	return r2


func _merge_action_from_png_if_missing(
	frames: SpriteFrames, action: StringName, slot: String, variant: StringName
) -> void:
	if frames == null:
		return
	# If the action already exists, nothing to do.
	if frames.has_animation(StringName(str(action, "_front"))):
		return

	var png_path := "%s/%s/%s/%s.png" % [source_root, String(action), slot, String(variant)]
	if not ResourceLoader.exists(png_path):
		return

	var tex := load(png_path) as Texture2D
	if tex == null:
		return

	var cell := Vector2i(32, 32)
	for row_i in range(_DIRS.size()):
		var dir := _DIRS[row_i]
		var anim_name := StringName(str(action, "_", dir))
		if frames.has_animation(anim_name):
			continue
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 6.0)
		frames.set_animation_loop(anim_name, not (action in [&"swing", &"use"]))

		for col_i in range(4):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2i(col_i * cell.x, row_i * cell.y, cell.x, cell.y)
			frames.add_frame(anim_name, at)


func _build_frames_from_png_sheets(slot: String, variant: StringName) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var cell := Vector2i(32, 32)
	var order_dirs: Array[StringName] = _DIRS

	# Our export convention is: res://assets/characters/base/<action>/<slot>/<variant>.png
	# Where action is one of: move, carry, use, swing
	var actions := [&"move", &"carry", &"use", &"swing"]
	for action in actions:
		var png_path := "%s/%s/%s/%s.png" % [source_root, String(action), slot, String(variant)]
		if not ResourceLoader.exists(png_path):
			continue
		var tex := load(png_path) as Texture2D
		if tex == null:
			continue

		for row_i in range(order_dirs.size()):
			var dir := order_dirs[row_i]
			var anim_name := StringName(str(action, "_", dir))
			if not frames.has_animation(anim_name):
				frames.add_animation(anim_name)
				frames.set_animation_speed(anim_name, 6.0)
				# Combat/action animations should not loop.
				frames.set_animation_loop(anim_name, not (action in [&"swing", &"use"]))

			for col_i in range(4):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2i(col_i * cell.x, row_i * cell.y, cell.x, cell.y)
				frames.add_frame(anim_name, at)

	return frames


func _resolve_directed(directed: StringName) -> StringName:
	# Map higher-level animation requests to the actual animations present in generated SpriteFrames.
	# Generated convention: move_<dir>, carry_<dir>, use_<dir>, swing_<dir>
	# Requested by gameplay: idle/carry_idle/carry_move/use/swing
	var parts: Dictionary = _split_directed(directed)
	var base: StringName = parts.get("base", &"idle") as StringName
	var dir: StringName = parts.get("dir", &"front") as StringName
	var resolved := directed

	match base:
		&"idle":
			resolved = StringName(str("move_", dir))
		&"carry_idle":
			resolved = StringName(str("carry_", dir))
		&"carry_move":
			resolved = StringName(str("carry_", dir))
		&"use":
			# Prefer dedicated use animation (fallback handled per-layer in _play_or_fallback).
			resolved = StringName(str("use_", dir))
		&"move":
			resolved = StringName(str("move_", dir))
		&"carry":
			resolved = StringName(str("carry_", dir))
		&"swing":
			resolved = StringName(str("swing_", dir))

	# Otherwise: assume the input is already a real animation name.
	return resolved


func _apply_hold_policy(
	requested_base: StringName, prev_requested_base: StringName, prev_resolved_directed: StringName
) -> void:
	# Implements the sprite-work-saving rules:
	# - idle: play move_*, freeze frame 0
	# - carry_idle: play carry_*, freeze frame 0
	# All other actions: ensure clock is playing normally.
	var clock := get_clock_sprite()
	if clock == null:
		return

	# Clear pending freeze if the animation changed.
	if _pending_freeze and clock.animation != _pending_freeze_anim:
		_pending_freeze = false
		_pending_freeze_anim = &""

	match requested_base:
		&"idle", &"carry_idle":
			_pending_freeze = false
			_pending_freeze_anim = &""
			clock.speed_scale = 0.0
			clock.stop()
			clock.frame = 0
		_:
			_pending_freeze = false
			_pending_freeze_anim = &""
			# Normalize locomotion speed even if generated SpriteFrames were built with different speeds.
			if requested_base in [&"move", &"carry_move", &"use"]:
				_set_clock_target_fps(clock, 6.0)
			else:
				if float(clock.speed_scale) == 0.0:
					clock.speed_scale = 1.0
			if not clock.is_playing():
				clock.play(clock.animation)

			# If we were previously frozen on an idle frame, starting movement from frame 0
			# looks like a 1-frame delay (because frame 0 == idle pose). Nudge to frame 1.
			if (
				prev_requested_base in [&"idle", &"carry_idle"]
				and requested_base in [&"move", &"carry_move"]
				and prev_resolved_directed != &""
				and clock.animation == prev_resolved_directed
				and clock.sprite_frames != null
			):
				var frame_count := int(clock.sprite_frames.get_frame_count(clock.animation))
				if frame_count > 1:
					clock.frame = 1
					clock.frame_progress = 0.0


func _update_pending_freeze() -> void:
	if not _pending_freeze:
		return
	var clock := get_clock_sprite()
	if clock == null:
		return
	# Only freeze if we are still on the intended animation.
	if clock.animation != _pending_freeze_anim:
		_pending_freeze = false
		_pending_freeze_anim = &""
		return
	if int(clock.frame) >= _pending_freeze_target_frame:
		_pending_freeze = false
		_pending_freeze_anim = &""
		clock.speed_scale = 0.0
		clock.stop()
		clock.frame = _pending_freeze_target_frame


func _set_clock_target_fps(clock: AnimatedSprite2D, desired_fps: float) -> void:
	if clock == null:
		return
	if clock.sprite_frames == null:
		clock.speed_scale = 1.0
		return
	var base_fps := float(clock.sprite_frames.get_animation_speed(clock.animation))
	if base_fps <= 0.0:
		clock.speed_scale = 1.0
		return
	clock.speed_scale = desired_fps / base_fps


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
