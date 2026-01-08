class_name QuestUiHelper
extends RefCounted

## Shared helper for quest UI rendering (QuestPanel + RewardPopup).
## Focus: item-count objectives (icon + progress/target formatting).

static var _item_cache: Dictionary = {}  # StringName -> ItemData (or null)


static func format_progress(progress: int, target: int) -> String:
	var t := maxi(1, int(target))
	var p := clampi(int(progress), 0, t)
	return "%d/%d" % [p, t]


static func resolve_item_data(item_id: StringName) -> ItemData:
	if String(item_id).is_empty():
		return null
	if _item_cache.has(item_id):
		return _item_cache[item_id] as ItemData

	var id_str := String(item_id)
	var candidates := PackedStringArray(
		[
			"res://game/entities/items/resources/%s.tres" % id_str,
			"res://game/entities/tools/data/%s.tres" % id_str,
		]
	)
	var resolved: ItemData = null
	for p in candidates:
		if ResourceLoader.exists(p):
			var res := load(p)
			if res is ItemData:
				resolved = res as ItemData
				break
	_item_cache[item_id] = resolved
	return resolved


static func build_item_count_display(o: QuestObjectiveItemCount, progress: int) -> Dictionary:
	if o == null:
		return {}
	var item := resolve_item_data(o.item_id)
	var target := maxi(1, int(o.target_count))
	var p := maxi(0, int(progress))
	var icon: Texture2D = null
	var item_name := String(o.item_id)
	if item != null:
		icon = item.icon
		if not item.display_name.is_empty():
			item_name = item.display_name

	return {
		"icon": icon,
		"item_name": item_name,
		"progress": clampi(p, 0, target),
		"target": target,
		"count_text": format_progress(p, target),
	}


static func get_next_item_count_objective_display(
	quest_id: StringName, completed_step_index: int, quest_manager: Node
) -> Dictionary:
	if quest_manager == null:
		return {}
	if String(quest_id).is_empty():
		return {}
	if not quest_manager.has_method("get_quest_definition"):
		return {}

	var def: QuestResource = quest_manager.call("get_quest_definition", quest_id) as QuestResource
	if def == null:
		return {}
	var next_idx := int(completed_step_index) + 1
	if next_idx < 0 or next_idx >= def.steps.size():
		return {}
	var st: QuestStep = def.steps[next_idx]
	if st == null or st.objective == null:
		return {}
	if not (st.objective is QuestObjectiveItemCount):
		return {}

	var o := st.objective as QuestObjectiveItemCount
	var progress := 0
	if quest_manager.has_method("get_objective_progress"):
		progress = int(quest_manager.call("get_objective_progress", quest_id, next_idx))
	return build_item_count_display(o, progress)
