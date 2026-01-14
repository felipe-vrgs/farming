@tool
extends EditorScript

## Builds SpriteFrames resources from exported tool animation PNG sheets.
##
## Expects per tool:
##   res://assets/tools/<tool>/anims/<tier>.png
## Where each PNG is a sheet of 32x32 cells:
##   - 4 rows: directions (front, left, right, back)
##   - N columns: animation frames (e.g. 3)
##
## Output:
##   res://assets/tools/<tool>/<tool>.tres
## With animations named: "<tier>_<dir>" (e.g. "gold_front")

const TOOLS_ROOT := "res://assets/tools"
const ANIMS_DIR := "anims"

const CELL := Vector2i(32, 32)
const DIRS: Array[StringName] = [&"front", &"left", &"right", &"back"]
const ROWS := 4


func _run() -> void:
	var built := build_all(TOOLS_ROOT)
	print("Built tool SpriteFrames: %d" % built)


func build_all(root: String) -> int:
	var built := 0
	var tool_dirs := _list_dirs(root)
	for tool in tool_dirs:
		var anims_path := "%s/%s/%s" % [root, tool, ANIMS_DIR]
		if DirAccess.open(anims_path) == null:
			# Tool doesn't use the new anims pipeline (yet).
			continue
		var sf := _build_spriteframes_for_tool(tool, anims_path)
		if sf == null:
			continue
		var out_path := "%s/%s/%s.tres" % [root, tool, tool]
		if _save_spriteframes(out_path, sf):
			built += 1
	return built


func _build_spriteframes_for_tool(tool: String, anims_path: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var pngs := _list_pngs(anims_path)
	if pngs.is_empty():
		push_warning("Tool '%s' has no tier PNGs in %s" % [tool, anims_path])
		return null

	for png in pngs:
		var tier := png.get_basename()
		var path := "%s/%s" % [anims_path, png]
		var tex := load(path) as Texture2D
		if tex == null:
			push_warning("Failed to load tool tier PNG: %s" % path)
			continue

		var w := int(tex.get_width())
		var h := int(tex.get_height())
		if w < CELL.x or h < CELL.y * ROWS:
			push_warning("Tool tier PNG too small: %s (%dx%d)" % [path, w, h])
			continue

		var cols := int(floor(float(w) / float(CELL.x)))
		if cols <= 0:
			continue
		if w % CELL.x != 0:
			push_warning("Tool tier PNG width not divisible by %d: %s (%dpx)" % [CELL.x, path, w])
		if h % CELL.y != 0:
			push_warning("Tool tier PNG height not divisible by %d: %s (%dpx)" % [CELL.y, path, h])

		for row_i in range(ROWS):
			var dir := DIRS[row_i]
			var anim := StringName(str(tier, "_", dir))
			if not sf.has_animation(anim):
				sf.add_animation(anim)
				sf.set_animation_speed(anim, 6.0)
				sf.set_animation_loop(anim, false)

			for col_i in range(cols):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2i(col_i * CELL.x, row_i * CELL.y, CELL.x, CELL.y)
				sf.add_frame(anim, at)

	return sf


func _save_spriteframes(path: String, sf: SpriteFrames) -> bool:
	if sf == null:
		return false
	var err := ResourceSaver.save(sf, path)
	if err != OK:
		push_error("Failed to save SpriteFrames: %s (err=%s)" % [path, str(err)])
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
	out.sort()
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
	out.sort()
	return out
