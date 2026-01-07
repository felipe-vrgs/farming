@tool
class_name InventoryPanel
extends MarginContainer

const SLOT_SCENE: PackedScene = preload("res://game/ui/hotbar_slot/hotbar_slot.tscn")

@export var columns: int = 4
@export var slot_size: Vector2 = Vector2(20, 20)

@export_group("Preview (Editor)")
@export var preview_inventory: InventoryData = null:
	set(v):
		# In-editor: avoid mutating shared `.tres` resources.
		# Important: duplicate() returns a base Resource, so cast back to InventoryData.
		if v == null:
			preview_inventory = null
		else:
			preview_inventory = v.duplicate(true) as InventoryData
		_apply_preview()
@export var preview_selected_index: int = -1:
	set(v):
		preview_selected_index = v
		_apply_preview()

signal slot_clicked(index: int)

var player: Player = null
var inventory: InventoryData = null
var selected_index: int = -1

@onready var grid: GridContainer = %Grid


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if grid != null:
		grid.columns = maxi(1, columns)
	_apply_preview()


func rebind(new_player: Player = null) -> void:
	player = new_player

	rebind_inventory(player.inventory if player != null else null)


func rebind_inventory(new_inventory: InventoryData) -> void:
	# Disconnect old inventory signal.
	if (
		inventory != null
		and is_instance_valid(inventory)
		and inventory.has_signal("contents_changed")
	):
		var cb := Callable(self, "_on_inventory_contents_changed")
		if inventory.is_connected("contents_changed", cb):
			inventory.disconnect("contents_changed", cb)

	# Tool/editor safety: avoid connecting signals on non-inventory resources.
	if new_inventory == null or not (new_inventory is InventoryData):
		inventory = null
	else:
		inventory = new_inventory

	# Connect new inventory signal.
	if inventory != null and inventory.has_signal("contents_changed"):
		var cb := Callable(self, "_on_inventory_contents_changed")
		if not inventory.is_connected("contents_changed", cb):
			inventory.connect("contents_changed", cb)

	_rebuild()


func _on_inventory_contents_changed() -> void:
	_rebuild()


func set_selected_index(index: int) -> void:
	selected_index = index
	_apply_selection_highlights()


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
		slot_view.custom_minimum_size = slot_size
		if slot_view is Control:
			(slot_view as Control).mouse_filter = Control.MOUSE_FILTER_STOP
			(slot_view as Control).gui_input.connect(_on_slot_gui_input.bind(i))
		grid.add_child(slot_view)

		if slot_view is HotbarSlot:
			var s := slot_view as HotbarSlot
			s.set_hotkey("")
			s.set_highlight(i == selected_index)
			if data != null and data.item_data != null and data.count > 0:
				s.set_item(data.item_data, data.count)
			else:
				s.set_item(null, 0)


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			selected_index = index
			_apply_selection_highlights()
			slot_clicked.emit(index)


func _apply_selection_highlights() -> void:
	if grid == null:
		return
	var children := grid.get_children()
	for i in range(children.size()):
		var c := children[i]
		if c is HotbarSlot:
			(c as HotbarSlot).set_highlight(i == selected_index)


func _apply_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if preview_inventory == null:
		return

	rebind_inventory(preview_inventory)
	set_selected_index(preview_selected_index)
