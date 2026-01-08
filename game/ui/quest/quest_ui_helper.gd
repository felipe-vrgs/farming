class_name QuestUiHelper
extends RefCounted

## Shared helper for quest UI rendering (QuestPanel + RewardPopup).
## Focus: item-count objectives (icon + progress/target formatting).

const _OBJECTIVE_CONTEXT: Script = preload("res://game/ui/quest/quest_objective_context_helper.gd")

static var _item_cache: Dictionary = {}  # StringName -> ItemData (or null)


class ItemCountDisplay:
	var action: String
	var icon: Texture2D
	var item_name: String
	var progress: int
	var target: int
	var count_text: String


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


static func build_item_count_display(o: QuestObjectiveItemCount, progress: int) -> ItemCountDisplay:
	if o == null:
		return null
	var item := resolve_item_data(o.item_id)
	var target := maxi(1, int(o.target_count))
	var p := maxi(0, int(progress))
	var icon: Texture2D = null
	var item_name := String(o.item_id)
	if item != null:
		icon = item.icon
		if not item.display_name.is_empty():
			item_name = item.display_name

	var icd = ItemCountDisplay.new()
	icd.action = String(_OBJECTIVE_CONTEXT.call("get_action_label", o))
	icd.icon = icon
	icd.item_name = item_name
	icd.progress = clampi(p, 0, target)
	icd.target = target
	icd.count_text = format_progress(p, target)
	return icd


static func get_next_item_count_objective_display(
	quest_id: StringName, completed_step_index: int, quest_manager: Node
) -> ItemCountDisplay:
	if quest_manager == null:
		return null
	if String(quest_id).is_empty():
		return null
	if not quest_manager.has_method("get_quest_definition"):
		return null

	var def: QuestResource = quest_manager.call("get_quest_definition", quest_id) as QuestResource
	if def == null:
		return null
	var next_idx := int(completed_step_index) + 1
	if next_idx < 0 or next_idx >= def.steps.size():
		return null
	var st: QuestStep = def.steps[next_idx]
	if st == null or st.objective == null:
		return null
	if not (st.objective is QuestObjectiveItemCount):
		return null

	var o := st.objective as QuestObjectiveItemCount
	var progress := 0
	if quest_manager.has_method("get_objective_progress"):
		progress = int(quest_manager.call("get_objective_progress", quest_id, next_idx))
	return build_item_count_display(o, progress)
