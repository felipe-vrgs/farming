class_name HouseExteriorTierController
extends Node

@export var metadata_key: StringName = &"frieren_house"
@export var tier_variant_map: Array[int] = []

var _current_tier: int = -1


func _ready() -> void:
	set_tier(_load_saved_tier())


func set_tier(next_tier: int) -> void:
	var tier = max(0, int(next_tier))
	if _current_tier == tier:
		return
	_current_tier = tier
	_apply_variant_for_tier(tier)


func _load_saved_tier() -> int:
	if Runtime == null or Runtime.save_manager == null:
		return 0
	var ls: LevelSave = Runtime.save_manager.load_session_level_save(Enums.Levels.FRIEREN_HOUSE)
	if ls == null:
		return 0
	return int(ls.frieren_house_tier)


func _apply_variant_for_tier(tier: int) -> void:
	var variant_index := _map_tier_to_variant(tier)
	var targets: Array[Node] = []
	var scene := get_tree().current_scene
	if scene != null:
		_collect_targets(scene, targets)
	for node in targets:
		if node == null or not is_instance_valid(node):
			continue
		if "variant_index" in node:
			node.set("variant_index", variant_index)


func _map_tier_to_variant(tier: int) -> int:
	if tier_variant_map.is_empty():
		return tier
	if tier < 0:
		return tier_variant_map[0]
	if tier >= tier_variant_map.size():
		return tier_variant_map[tier_variant_map.size() - 1]
	return int(tier_variant_map[tier])


func _collect_targets(root: Node, out: Array[Node]) -> void:
	if root.has_meta(metadata_key) and bool(root.get_meta(metadata_key)):
		out.append(root)
	for child in root.get_children():
		if child is Node:
			_collect_targets(child as Node, out)
