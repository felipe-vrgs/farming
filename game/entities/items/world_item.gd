class_name WorldItem
extends Node


static func spawn(
	parent: Node, data: ItemData, loot_count: int, spawn_count: int, position: Vector2
) -> void:
	if parent == null or data == null:
		return

	var drops := maxi(1, spawn_count)
	# Load scene dynamically to avoid cyclic reference if this script is used by the scene
	var scene = load("res://game/entities/items/item.tscn")
	if scene == null:
		push_error("WorldItem: Could not load item.tscn")
		return

	for i in range(drops):
		var item = scene.instantiate()
		item.item_data = data
		item.count = loot_count

		# Random offset
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		item.global_position = position + offset
		parent.add_child(item)
