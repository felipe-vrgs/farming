@tool
extends EditorScript

## Generates per-tier ToolData resources from tool icon exports.
##
## For each configured tool:
## - Reads template ToolData (baseline gameplay settings)
## - Scans res://assets/tools/<tool>/icons/*.png (tier inferred from filename)
## - Writes res://game/entities/tools/data/<tool>/<tool>_<tier>.tres
##
## The generated ToolData is wired to:
## - icon: Texture2D at icons/<tier>.png
## - tool_sprite_frames: res://assets/tools/<tool>/<tool>.tres
## - tier: "<tier>" so ToolVisuals plays "<tier>_<dir>"
## - tier_color: per-tier VFX tint (swish, glow, etc.)

const OUT_DIR := "res://game/entities/tools/data"
const TOOLS_ROOT := "res://assets/tools"

const TOOL_CONFIG := {
	"axe":
	{
		"template": "res://game/entities/tools/data/axe/axe_iron.tres",
		"icons_dir": "res://assets/tools/axe/icons",
		"frames": "res://assets/tools/axe/axe.tres",
	},
	"pickaxe":
	{
		"template": "res://game/entities/tools/data/pickaxe/pickaxe_iron.tres",
		"icons_dir": "res://assets/tools/pickaxe/icons",
		"frames": "res://assets/tools/pickaxe/pickaxe.tres",
	},
}

const TIER_ORDER: Array[StringName] = [&"iron", &"gold", &"platinum", &"ruby"]


func _run() -> void:
	_ensure_dir(OUT_DIR)
	var written := 0

	for tool in TOOL_CONFIG.keys():
		var cfg: Dictionary = TOOL_CONFIG[tool]
		_ensure_dir("%s/%s" % [OUT_DIR, String(tool)])
		written += _generate_for_tool(String(tool), cfg)

	print("Generated tiered ToolData: %d" % written)


func _generate_for_tool(tool: String, cfg: Dictionary) -> int:
	var template_path := String(cfg.get("template", ""))
	var icons_dir := String(cfg.get("icons_dir", ""))
	var frames_path := String(cfg.get("frames", ""))

	if template_path.is_empty() or icons_dir.is_empty() or frames_path.is_empty():
		push_warning("Tool config missing paths for '%s'." % tool)
		return 0

	var template_any := load(template_path)
	var template: ToolData = template_any as ToolData
	if template == null:
		push_warning("Failed to load template ToolData: %s" % template_path)
		return 0

	var frames_any := load(frames_path)
	var frames := frames_any as SpriteFrames
	if frames == null:
		push_warning(
			"Failed to load SpriteFrames: %s (run build_tool_spriteframes first)" % frames_path
		)
		return 0

	if DirAccess.open(icons_dir) == null:
		push_warning("Missing icons dir for '%s': %s" % [tool, icons_dir])
		return 0

	var tiers := _list_png_basenames(icons_dir)
	if tiers.is_empty():
		push_warning("No tier icons found for '%s' in %s" % [tool, icons_dir])
		return 0

	var written := 0
	for tier_str in tiers:
		var tier := StringName(tier_str)
		var icon_path := "%s/%s.png" % [icons_dir, tier_str]
		var icon_tex := load(icon_path) as Texture2D
		if icon_tex == null:
			push_warning("Failed to load icon: %s" % icon_path)
			continue

		var td := template.duplicate(true) as ToolData
		if td == null:
			continue

		td.id = StringName("%s_%s" % [tool, tier_str])
		var tier_title := String(tier_str).capitalize()
		var base_name := template.display_name if template.display_name != "" else tool.capitalize()
		td.display_name = "%s %s" % [tier_title, base_name]

		# Tier wiring
		td.tool_sprite_frames = frames
		td.tier = tier
		td.tier_color = _tier_color_for(tier)

		# Per-variant icon
		td.icon = icon_tex

		var out_path := "%s/%s/%s_%s.tres" % [OUT_DIR, tool, tool, tier_str]
		var err := ResourceSaver.save(td, out_path)
		if err != OK:
			push_error("Failed saving ToolData: %s (err=%s)" % [out_path, str(err)])
			continue
		written += 1

	return written


func _tier_index(tier: StringName) -> int:
	var s := String(tier)
	for i in range(TIER_ORDER.size()):
		if String(TIER_ORDER[i]) == s:
			return i + 1
	# Unknown tier: put after known ones
	return TIER_ORDER.size() + 1


func _tier_color_for(tier: StringName) -> Color:
	var t := tier
	if String(t).is_empty():
		t = &"iron"
	match t:
		&"iron":
			return Color(0.75, 0.78, 0.82, 1.0)
		&"gold":
			return Color(1.0, 0.85, 0.25, 1.0)
		&"platinum":
			return Color(0.75, 0.92, 1.0, 1.0)
		&"ruby":
			return Color(1.0, 0.25, 0.45, 1.0)
	return Color.WHITE


func _list_png_basenames(dir_path: String) -> Array[String]:
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
			out.append(name.get_basename())
	d.list_dir_end()
	out.sort()
	return out


func _ensure_dir(dir_path: String) -> void:
	var abs := _to_abs(dir_path)
	if DirAccess.dir_exists_absolute(abs):
		return
	DirAccess.make_dir_recursive_absolute(abs)


func _to_abs(path: String) -> String:
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path
