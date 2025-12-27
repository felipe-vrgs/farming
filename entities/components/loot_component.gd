class_name LootComponent
extends Node2D

@export var loot_item: ItemData
@export var loot_count: int = 1

var _world_item_scene: PackedScene = preload("res://entities/items/world_item.tscn")

func spawn_loot() -> void:
	if loot_item == null:
		return

	for i in range(loot_count):
		var item = _world_item_scene.instantiate()
		item.item_data = loot_item
		# Random offset so items don't stack perfectly on top of each other
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		item.global_position = global_position + offset
		item.z_index = 99
		get_tree().root.add_child(item)
	get_parent().queue_free()