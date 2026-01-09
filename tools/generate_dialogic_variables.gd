@tool
extends EditorScript

## Generates/updates `ProjectSettings["dialogic/variables"]` so Dialogic's Variables editor
## shows our stable, runtime-backed variables for:
## - quests.<quest_id>.{active,completed,step}
## - relationships.<npc_id>.units
## - completed_timelines.<timeline_path_segments...>
##
## This is intentionally a merge (non-destructive): we add missing keys/paths but do not
## clobber existing user-authored variables/defaults.

const _QUESTS_DIR := "res://game/data/quests"
const _NPC_CONFIGS_DIR := "res://game/entities/npc/configs"
const _TIMELINES_DIR := "res://game/globals/dialogue/timelines"


func _run() -> void:
	var vars_any: Variant = ProjectSettings.get_setting("dialogic/variables", {})
	var vars: Dictionary = vars_any if vars_any is Dictionary else {}

	var stats := {
		"quests_added": 0,
		"relationships_added": 0,
		"timelines_added": 0,
		"files_scanned": 0,
	}

	# Ensure roots exist.
	if not vars.has("quests") or not (vars["quests"] is Dictionary):
		vars["quests"] = {}
	if not vars.has("relationships") or not (vars["relationships"] is Dictionary):
		vars["relationships"] = {}
	if not vars.has("completed_timelines") or not (vars["completed_timelines"] is Dictionary):
		vars["completed_timelines"] = {}

	var quests_root: Dictionary = vars["quests"] as Dictionary
	var rel_root: Dictionary = vars["relationships"] as Dictionary
	var completed_root: Dictionary = vars["completed_timelines"] as Dictionary

	# Quests
	for qid in _collect_quest_ids(_QUESTS_DIR, stats):
		if String(qid).is_empty():
			continue
		stats["quests_added"] += _ensure_quest_schema(quests_root, qid)

	# Relationships
	for npc_id in _collect_npc_ids(_NPC_CONFIGS_DIR, stats):
		if String(npc_id).is_empty():
			continue
		stats["relationships_added"] += _ensure_relationship_schema(rel_root, npc_id)

	# Timelines (Dialogic auto-vars for completion)
	for segments in _collect_timeline_segments(_TIMELINES_DIR, stats):
		if segments.is_empty():
			continue
		stats["timelines_added"] += _ensure_completed_timeline_schema(completed_root, segments)

	ProjectSettings.set_setting("dialogic/variables", vars)
	ProjectSettings.save()

	_try_refresh_dialogic_variables_editor(vars)

	print(
		(
			"Dialogic variables updated: +%d quests, +%d relationships, +%d timelines (scanned %d files)"
			% [
				int(stats["quests_added"]),
				int(stats["relationships_added"]),
				int(stats["timelines_added"]),
				int(stats["files_scanned"]),
			]
		)
	)
	print("If Dialogic Variables UI doesn't refresh, close/reopen the Variables editor dock.")


func _ensure_quest_schema(quests_root: Dictionary, quest_id: StringName) -> int:
	# Returns 1 if we created a new quest entry, 0 otherwise.
	if quests_root == null:
		return 0
	var key := String(quest_id)
	var created := 0
	if not quests_root.has(key) or not (quests_root[key] is Dictionary):
		quests_root[key] = {}
		created = 1
	var d: Dictionary = quests_root[key] as Dictionary
	if not d.has("active"):
		d["active"] = false
	if not d.has("completed"):
		d["completed"] = false
	if not d.has("step"):
		d["step"] = 0
	return created


func _ensure_relationship_schema(rel_root: Dictionary, npc_id: StringName) -> int:
	# Returns 1 if we created a new npc entry, 0 otherwise.
	if rel_root == null:
		return 0
	var key := String(npc_id)
	var created := 0
	if not rel_root.has(key) or not (rel_root[key] is Dictionary):
		rel_root[key] = {}
		created = 1
	var d: Dictionary = rel_root[key] as Dictionary
	if not d.has("units"):
		d["units"] = 0
	return created


func _ensure_completed_timeline_schema(
	completed_root: Dictionary, segments: PackedStringArray
) -> int:
	# Ensures completed_timelines.<segments...> exists as a bool leaf (default false).
	# Returns 1 if we created the leaf, 0 if it already existed.
	if completed_root == null:
		return 0
	if segments.is_empty():
		return 0

	var d := completed_root
	for i in range(segments.size()):
		var k := String(segments[i]).strip_edges()
		if k.is_empty():
			continue
		var is_last := i == segments.size() - 1
		if is_last:
			if not d.has(k):
				d[k] = false
				return 1
			return 0
		if not d.has(k) or not (d[k] is Dictionary):
			d[k] = {}
		d = d[k] as Dictionary
	return 0


func _collect_quest_ids(dir_path: String, stats: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var da := DirAccess.open(dir_path)
	if da == null:
		return out
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry == "." or entry == ".." or entry.begins_with("."):
			entry = da.get_next()
			continue
		if da.current_is_dir():
			out.append_array(_collect_quest_ids("%s/%s" % [dir_path, entry], stats))
			entry = da.get_next()
			continue
		if entry.ends_with(".tres"):
			stats["files_scanned"] = int(stats.get("files_scanned", 0)) + 1
			var path := "%s/%s" % [dir_path, entry]
			var res := load(path)
			if res is QuestResource:
				var q := res as QuestResource
				if q != null and not String(q.id).is_empty():
					out.append(q.id)
		entry = da.get_next()
	da.list_dir_end()
	# Stable ordering.
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func _collect_npc_ids(dir_path: String, stats: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var da := DirAccess.open(dir_path)
	if da == null:
		return out
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry == "." or entry == ".." or entry.begins_with("."):
			entry = da.get_next()
			continue
		if da.current_is_dir():
			# No recursion needed for now.
			entry = da.get_next()
			continue
		if entry.ends_with(".tres"):
			# Avoid loading NpcConfig resources in tool scripts: if their script isn't @tool,
			# Godot can instantiate them as placeholders and method calls will fail.
			# Runtime also resolves configs by filename (`<npc_id>.tres`), so use that.
			if entry.ends_with("_inventory.tres"):
				entry = da.get_next()
				continue
			stats["files_scanned"] = int(stats.get("files_scanned", 0)) + 1
			var npc_id := StringName(entry.trim_suffix(".tres"))
			if not String(npc_id).is_empty():
				out.append(npc_id)
		entry = da.get_next()
	da.list_dir_end()
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func _collect_timeline_segments(dir_path: String, stats: Dictionary) -> Array[PackedStringArray]:
	# Returns arrays of segments, e.g. ["npcs","frieren","greeting"].
	var out: Array[PackedStringArray] = []
	var da := DirAccess.open(dir_path)
	if da == null:
		return out
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry == "." or entry == ".." or entry.begins_with("."):
			entry = da.get_next()
			continue
		if da.current_is_dir():
			out.append_array(_collect_timeline_segments("%s/%s" % [dir_path, entry], stats))
			entry = da.get_next()
			continue
		if entry.ends_with(".dtl"):
			stats["files_scanned"] = int(stats.get("files_scanned", 0)) + 1
			var path := "%s/%s" % [dir_path, entry]
			var rel := path.trim_prefix(_TIMELINES_DIR + "/")
			rel = rel.trim_suffix(".dtl")
			var segs := PackedStringArray(rel.split("/", false))
			if not segs.is_empty():
				out.append(segs)
		entry = da.get_next()
	da.list_dir_end()
	# Stable ordering by joined path.
	out.sort_custom(
		func(a: PackedStringArray, b: PackedStringArray) -> bool: return "/".join(a) < "/".join(b)
	)
	return out


func _try_refresh_dialogic_variables_editor(vars: Dictionary) -> void:
	# Best-effort: if the Dialogic Variables editor dock is open, reload its tree so the user
	# sees changes immediately without restarting the editor.
	if not Engine.is_editor_hint():
		return
	if vars == null:
		return
	var ei := get_editor_interface()
	if ei == null:
		return
	var root := ei.get_base_control()
	if root == null:
		return

	var stack: Array[Node] = [root as Node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null:
			continue
		# Variables editor scene root is named "VariablesEditor".
		if n.name == "VariablesEditor":
			var tree: Node = n.get_node_or_null(NodePath("Tree")) as Node
			if tree != null and tree.has_method("load_info"):
				tree.call("load_info", vars)
				return
		for c in n.get_children():
			if c is Node:
				stack.append(c as Node)
