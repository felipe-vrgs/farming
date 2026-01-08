class_name RewardPopup
extends Control

@onready var rewards_list: ItemList = %RewardsList


func _ready() -> void:
	# Must run while SceneTree is paused (GrantRewardState pauses the tree).
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_rewards(rows: Array[Dictionary]) -> void:
	if rewards_list == null:
		return
	rewards_list.clear()

	if rows == null or rows.is_empty():
		var idx := rewards_list.add_item("Nothing")
		rewards_list.set_item_selectable(idx, false)
		return

	for row in rows:
		if row == null:
			continue
		var text := String(row.get("text", "Reward"))
		var icon: Texture2D = row.get("icon") as Texture2D
		var idx := rewards_list.add_item(text, icon)
		rewards_list.set_item_selectable(idx, false)
