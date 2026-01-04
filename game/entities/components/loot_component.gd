class_name LootComponent
extends Node2D

@export var loot_item: ItemData
@export var loot_count: int = 1

var _world_item_scene: PackedScene = preload("res://game/entities/items/world_item.tscn")


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
	for i in range(loot_count):
		var item = _world_item_scene.instantiate()
		item.item_data = loot_item
		# Random offset so items don't stack perfectly on top of each other
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		item.global_position = global_position + offset
		parent.add_child(item)
	get_parent().queue_free()
