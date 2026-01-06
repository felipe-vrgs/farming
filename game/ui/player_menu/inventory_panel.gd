class_name InventoryPanel
extends MarginContainer

const SLOT_SCENE: PackedScene = preload("res://game/ui/hotbar_slot/hotbar_slot.tscn")

@export var columns: int = 4

var player: Player = null
var inventory: InventoryData = null

@onready var grid: GridContainer = %Grid


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if grid != null:
		grid.columns = maxi(1, columns)


func rebind(new_player: Player = null) -> void:
	player = new_player

	# Disconnect old inventory signal.
	if (
		inventory != null
		and inventory.contents_changed.is_connected(_on_inventory_contents_changed)
	):
		inventory.contents_changed.disconnect(_on_inventory_contents_changed)

	inventory = player.inventory if player != null else null

	# Connect new inventory signal.
	if inventory != null:
		inventory.contents_changed.connect(_on_inventory_contents_changed)

	_rebuild()


func _on_inventory_contents_changed() -> void:
	_rebuild()


func _rebuild() -> void:
	if grid == null:
		return

	for child in grid.get_children():
		child.queue_free()

	grid.columns = maxi(1, columns)

	if inventory == null:
		return

	var slots := inventory.slots
	for i in range(slots.size()):
		var data: InventorySlot = slots[i]

		var slot_view := SLOT_SCENE.instantiate()
		slot_view.custom_minimum_size = Vector2(48, 48)
		grid.add_child(slot_view)

		if slot_view is HotbarSlot:
			var s := slot_view as HotbarSlot
			s.set_hotkey("")
			if data != null and data.item_data != null and data.count > 0:
				s.set_item(data.item_data, data.count)
			else:
				s.set_item(null, 0)
