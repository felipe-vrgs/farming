@tool
class_name CutsceneOptions
extends Object

## Shared editor options + suggestion builders for Dialogic additions.

static func facing_fixed_options() -> Array:
	return [
		{"label":"Keep", "value": ""},
		{"label":"Left", "value": "left"},
		{"label":"Right", "value": "right"},
		{"label":"Front (down)", "value": "front"},
		{"label":"Back (up)", "value": "back"},
	]

static func _get_dialogic_dch_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var d = ProjectSettings.get_setting("dialogic/directories/dch_directory", {})
	if d is Dictionary:
		for k in d.keys():
			out.append(str(k))
	out.sort()
	return out

static func get_agent_id_suggestions(_filter_text: String) -> Dictionary:
	# Dialogic dynamic options expects: Dictionary[label] = { value = <string>, ... }
	var out: Dictionary = {}

	for id in _get_dialogic_dch_ids():
		out[id] = {"value": id}

	# Ensure player is always present as a convenience.
	if not out.has("player"):
		out["player"] = {"value": "player"}

	return out
