class_name QuestRewardItem
extends QuestReward

@export var item: ItemData = null
@export var count: int = 1:
	set(v):
		count = maxi(1, int(v))


func describe() -> String:
	if item == null:
		return "Item"
	return "Item: %s x%d" % [item.display_name, int(count)]


func grant(player: Node) -> void:
	if player == null or item == null:
		return
	if not ("inventory" in player):
		return
	if player.inventory == null:
		return
	var inv: InventoryData = player.inventory
	var remaining := inv.add_item(item, int(count))
	if remaining > 0 and UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast("Inventory full: reward partly lost (%d)." % int(remaining))
