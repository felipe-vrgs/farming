@tool
extends EditorScript

## Builds SpriteFrames resources from exported modular character PNG sheets.
##
## Expects:
##   res://assets/characters/base/<action>/<slot>/<variant>.png
## Where each PNG is a 4x4 sheet (cols=frames, rows=directions):
##   Row order: front, left, right, back
##   Each cell: 32x32
##
## Output:
##   res://assets/characters/generated/<slot>/<variant>.tres

const BASE_ROOT := "res://assets/characters/base"
const OUT_ROOT := "res://assets/characters/generated"

const ACTIONS: Array[StringName] = [
	&"move",
	&"carry",
	&"use",
	&"swing",
]

const DIRS: Array[StringName] = [&"front", &"left", &"right", &"back"]

const CELL_SIZE := Vector2i(32, 32)
const COLS := 4
const ROWS := 4


func _run() -> void:
	var built := build_all(BASE_ROOT, OUT_ROOT)
	print("Built SpriteFrames: %d" % built)


func build_all(base_root: String, out_root: String) -> int:
	var index := _scan_exports(base_root)
	var built := 0

	for key in index.keys():
		var parts := String(key).split("|", false)
		if parts.size() != 2:
			continue
		var slot := parts[0]
		var variant := parts[1]
		var sf := _build_spriteframes_for_slot_variant(base_root, slot, variant)
		if sf == null:
			continue
		if _save_spriteframes(out_root, slot, variant, sf):
			built += 1

	return built


func _scan_exports(base_root: String) -> Dictionary:
	# index key: "slot|variant" => true
	var index := {}
	for action in ACTIONS:
		var action_dir := "%s/%s" % [base_root, String(action)]
		if DirAccess.open(action_dir) == null:
			continue
		var slot_dirs := _list_dirs(action_dir)
		for slot in slot_dirs:
			var slot_dir := "%s/%s" % [action_dir, slot]
			var pngs := _list_pngs(slot_dir)
			for png in pngs:
				var variant := png.get_basename()  # strip .png
				var key := "%s|%s" % [slot, variant]
				index[key] = true
	return index


func _build_spriteframes_for_slot_variant(
	base_root: String, slot: String, variant: String
) -> SpriteFrames:
	var frames := SpriteFrames.new()

	for action in ACTIONS:
		var png_path := "%s/%s/%s/%s.png" % [base_root, String(action), slot, variant]
		if not ResourceLoader.exists(png_path):
			continue

		# Skip fully transparent sheets (common for hands_top on non-carry actions).
		if _is_fully_transparent_png(png_path):
			continue

		var tex := load(png_path) as Texture2D
		if tex == null:
			continue

		for row_i in range(ROWS):
			var dir := DIRS[row_i]
			var anim := StringName(str(action, "_", dir))
			if not frames.has_animation(anim):
				frames.add_animation(anim)
				frames.set_animation_speed(anim, _default_speed_for_action(action))
				frames.set_animation_loop(anim, _default_loop_for_action(action))

			for col_i in range(COLS):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2i(
					col_i * CELL_SIZE.x, row_i * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y
				)
				frames.add_frame(anim, at)

	return frames


func _save_spriteframes(out_root: String, slot: String, variant: String, sf: SpriteFrames) -> bool:
	if sf == null:
		return false
	var out_dir := "%s/%s" % [out_root, slot]
	_ensure_dir(out_dir)
	var path := "%s/%s.tres" % [out_dir, variant]
	var err := ResourceSaver.save(sf, path)
	if err != OK:
		push_error("Failed to save SpriteFrames: %s (err=%s)" % [path, str(err)])
		return false
	return true


func _default_speed_for_action(action: StringName) -> float:
	if action == &"move" or action == &"carry" or action == &"swing":
		return 6.0
	return 2.0


func _default_loop_for_action(action: StringName) -> bool:
	if action == &"swing":
		return false
	return true


func _list_dirs(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		if d.current_is_dir():
			out.append(name)
	d.list_dir_end()
	return out


func _list_pngs(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		if d.current_is_dir():
			continue
		if name.to_lower().ends_with(".png"):
			out.append(name)
	d.list_dir_end()
	return out


func _ensure_dir(dir_path: String) -> void:
	var abs := _to_abs(dir_path)
	if DirAccess.dir_exists_absolute(abs):
		return
	DirAccess.make_dir_recursive_absolute(abs)


func _to_abs(path: String) -> String:
	# Convert res:// to OS absolute path for DirAccess.*_absolute helpers.
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


func _is_fully_transparent_png(path: String) -> bool:
	var img := Image.new()
	# Use OS path to avoid editor warnings about Image loading.
	var abs := path
	if path.begins_with("res://"):
		abs = ProjectSettings.globalize_path(path)
	var err := img.load(abs)
	if err != OK:
		return false
	img.decompress()
	# If the PNG is not RGBA, assume it is not empty.
	if img.get_format() not in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF]:
		return false
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.0:
				return false
	return true
