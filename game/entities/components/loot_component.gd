class_name LootComponent
extends Node2D

@export var loot_item: ItemData
@export var loot_count: int = 1
@export var spawn_count: int = 1


func _get_level_entities_root() -> Node:
	# Loot must be parented under the active LevelRoot subtree, otherwise the save
	# capture (which scans LevelRoot roots) will never see these world drops.
	var scene := get_tree().current_scene
	if scene is LevelRoot:
		return (scene as LevelRoot).get_entities_root()
	return scene if scene != null else get_tree().root


func spawn_loot() -> void:
	if loot_item == null:
		return

	var parent := _get_level_entities_root()
	WorldItem.spawn(parent, loot_item, loot_count, spawn_count, global_position)
	get_parent().queue_free()
