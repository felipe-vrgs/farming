class_name QuestUiHelper
extends RefCounted

## Shared helper for quest UI rendering (QuestPanel + RewardPopup).
## Focus: item-count objectives (icon + progress/target formatting).

const _OBJECTIVE_CONTEXT: Script = preload("res://game/ui/quest/quest_objective_context_helper.gd")
const _MONEY_ICON: Texture2D = preload("res://assets/icons/money.png")
const _HEART_ATLAS: Texture2D = preload("res://assets/icons/heart.png")
const _HEART_REGION := Rect2i(0, 0, 16, 16)

static var _item_cache: Dictionary = {}  # StringName -> ItemData (or null)


class ObjectiveDisplay:
	var text: String = ""
	var icon: Texture2D = null
	# Optional: when set, UIs can render an animated NPC portrait instead of a static icon.
	var npc_id: StringName = &""
	# Optional: progress metadata (not always shown)
	var progress: int = 0
	var target: int = 0


class RewardDisplay:
	# e.g. &"item", &"money", &"relationship"
	var kind: StringName = &""
	var text: String = ""
	var icon: Texture2D = null
	# For relationship rewards, which NPC was affected.
	var npc_id: StringName = &""
	# Relationship rewards are measured in half-hearts (units).
	var delta_units: int = 0


class ItemCountDisplay:
	var action: String
	var icon: Texture2D
	var item_name: String
	# Optional: when set, UIs can render an animated NPC portrait instead of a static icon.
	var npc_id: StringName = &""
	var progress: int
	var target: int
	var count_text: String


static func safe_describe_objective(obj: Resource, fallback: String = "") -> String:
	# Tool UIs can run in the editor with placeholder resources (script not loaded).
	# Calling methods on those errors, so we guard and fall back.
	if obj == null:
		return fallback
	if Engine.is_editor_hint() and obj.get_script() == null:
		return fallback
	if obj.has_method("describe"):
		var s := String(obj.call("describe")).strip_edges()
		return s if not s.is_empty() else fallback
	return fallback


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


static func resolve_npc_icon(npc_id: StringName) -> Texture2D:
	if String(npc_id).is_empty():
		return null
	return NpcVisualsHelper.resolve_icon(npc_id)


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


static func build_talk_display(o: QuestObjectiveTalk, progress: int) -> ItemCountDisplay:
	if o == null:
		return null
	var target := maxi(1, int(o.target_count))
	var p := maxi(0, int(progress))

	var icd := ItemCountDisplay.new()
	icd.action = String(_OBJECTIVE_CONTEXT.call("get_action_label", o))
	icd.icon = resolve_npc_icon(o.npc_id)
	icd.item_name = String(o.npc_id)
	icd.npc_id = o.npc_id
	icd.progress = clampi(p, 0, target)
	icd.target = target
	# Keep it compact: count text is only useful if target_count > 1.
	icd.count_text = format_progress(p, target) if target > 1 else ""
	return icd


static func build_objective_display_for_quest_step(
	quest_id: StringName, step_idx: int, quest_manager: Node
) -> ObjectiveDisplay:
	# Returns the objective line for a specific quest step.
	# Best-effort: fill icon/npc_id based on objective type.
	if quest_manager == null:
		return null
	if String(quest_id).is_empty():
		return null
	if step_idx < 0:
		return null
	if not quest_manager.has_method("get_quest_definition"):
		return null

	var def: QuestResource = quest_manager.call("get_quest_definition", quest_id) as QuestResource
	if def == null or def.steps == null:
		return null
	if step_idx >= def.steps.size():
		return null

	var st: QuestStep = def.steps[step_idx]
	if st == null:
		return null

	var progress := 0
	if quest_manager.has_method("get_objective_progress"):
		progress = int(quest_manager.call("get_objective_progress", quest_id, step_idx))

	var out := ObjectiveDisplay.new()

	if st.objective != null:
		out.target = maxi(1, int(st.objective.target_count))
		out.progress = maxi(0, int(progress))
		var label := safe_describe_objective(st.objective, "Objective")

		if st.objective is QuestObjectiveItemCount:
			var o := st.objective as QuestObjectiveItemCount
			var item := resolve_item_data(o.item_id)
			if item != null:
				out.icon = item.icon
				if not item.display_name.is_empty():
					# Replace raw item id with display name (best-effort).
					label = label.replace(String(o.item_id), item.display_name)
		elif st.objective is QuestObjectiveTalk:
			var o2 := st.objective as QuestObjectiveTalk
			out.icon = resolve_npc_icon(o2.npc_id)
			out.npc_id = o2.npc_id

		# Always include progress in objective display text (UI decides whether to show it).
		out.text = "%s (%s)" % [label, format_progress(out.progress, out.target)]
		return out

	# Fallback: plain step description.
	out.text = String(st.description).strip_edges()
	if out.text.is_empty():
		out.text = "Objective"
	return out


static func build_next_objective_display(
	quest_id: StringName, completed_step_index: int, quest_manager: Node
) -> ObjectiveDisplay:
	# Event uses "completed step" semantics; we want to show the *next* step.
	return build_objective_display_for_quest_step(
		quest_id, int(completed_step_index) + 1, quest_manager
	)


static func build_reward_displays(rewards: Array) -> Array[RewardDisplay]:
	if rewards == null or rewards.is_empty():
		return []
	var out: Array[RewardDisplay] = []
	for r in rewards:
		if r == null:
			continue
		if r is QuestRewardItem:
			var ri := r as QuestRewardItem
			if ri.item == null:
				continue
			var d := RewardDisplay.new()
			d.kind = &"item"
			d.icon = ri.item.icon
			var cnt := maxi(1, int(ri.count))
			var name := ri.item.display_name
			if name.is_empty():
				name = "Item"
			d.text = ("%s x%d" % [name, cnt]) if cnt != 1 else name
			out.append(d)
		elif r is QuestRewardMoney:
			var rm := r as QuestRewardMoney
			var amt := int(rm.amount)
			var d := RewardDisplay.new()
			d.kind = &"money"
			d.icon = _MONEY_ICON
			d.text = "+%d money" % amt if amt >= 0 else "%d money" % amt
			out.append(d)
		elif r is QuestRewardRelationship:
			var rr := r as QuestRewardRelationship
			var d := RewardDisplay.new()
			d.kind = &"relationship"
			d.icon = _make_heart_icon()
			d.npc_id = rr.npc_id
			d.delta_units = int(rr.delta_units)
			d.text = "%s Relationship" % _format_relationship_delta(int(rr.delta_units))
			out.append(d)
	return out


static func _make_heart_icon() -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = _HEART_ATLAS
	at.region = _HEART_REGION
	return at


static func _format_relationship_delta(units: int) -> String:
	# Units are half-hearts: 2 units = 1 heart.
	var s := "+" if int(units) >= 0 else "-"
	var absu := absi(int(units))
	var whole := absu / 2.0
	var half := absu % 2
	if half == 0:
		return "%s%d" % [s, whole]
	if whole == 0:
		return "%s\u00bd" % s
	return "%s%d\u00bd" % [s, whole]


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


static func get_next_objective_display(
	quest_id: StringName, completed_step_index: int, quest_manager: Node
) -> ItemCountDisplay:
	# Generalized version of get_next_item_count_objective_display that can return
	# displays for other objective types (e.g. talk-to-NPC).
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

	var progress := 0
	if quest_manager.has_method("get_objective_progress"):
		progress = int(quest_manager.call("get_objective_progress", quest_id, next_idx))

	if st.objective is QuestObjectiveItemCount:
		return build_item_count_display(st.objective as QuestObjectiveItemCount, progress)
	if st.objective is QuestObjectiveTalk:
		return build_talk_display(st.objective as QuestObjectiveTalk, progress)

	return null
