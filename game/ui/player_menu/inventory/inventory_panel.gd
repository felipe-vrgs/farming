@tool
class_name InventoryPanel
extends MarginContainer

const SLOT_SCENE: PackedScene = preload("res://game/ui/hotbar_slot/hotbar_slot.tscn")

@export var columns: int = 4
@export var slot_size: Vector2 = Vector2(20, 20)
@export var is_editable: bool = true

## If > 0, renders additional empty/locked slots up to this count.
## Useful for showing future inventory expansion capacity.
@export var display_slot_count: int = -1

## Optional hotkey labels for the first row (0..columns-1).
## Typically passed from PlayerInputConfig (1..0).
@export var hotkeys: Array[String] = []
@export var show_hotkeys_on_first_row: bool = true
@export var locked_slot_tooltip: String = "Locked slot"

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
signal slot_focused(index: int)

var player: Player = null
var inventory: InventoryData = null
var selected_index: int = -1
var moving_source_index: int = -1

@onready var grid: GridContainer = %Grid


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if grid != null:
		grid.columns = maxi(1, columns)
	_apply_preview()


func rebind(new_player: Player = null) -> void:
	player = new_player

	_refresh_hotkeys()
	rebind_inventory(player.inventory if player != null else null)


func _refresh_hotkeys() -> void:
	# Best-effort: show the same hotkey row as the HUD hotbar (1..0).
	hotkeys = []
	if player == null or not is_instance_valid(player):
		return
	if player.player_input_config == null:
		return

	var actions := [
		player.player_input_config.action_hotbar_1,
		player.player_input_config.action_hotbar_2,
		player.player_input_config.action_hotbar_3,
		player.player_input_config.action_hotbar_4,
		player.player_input_config.action_hotbar_5,
		player.player_input_config.action_hotbar_6,
		player.player_input_config.action_hotbar_7,
		player.player_input_config.action_hotbar_8,
		player.player_input_config.action_hotbar_9,
		player.player_input_config.action_hotbar_0,
	]
	for a in actions:
		hotkeys.append(_get_key_text(a))


func _get_key_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return ""


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
	# Avoid getting "stuck" holding a slot after a drag-drop swap.
	moving_source_index = -1
	_rebuild()


func set_selected_index(index: int) -> void:
	selected_index = index
	_apply_slot_states()


func _rebuild() -> void:
	if grid == null:
		return

	for child in grid.get_children():
		# Important: queue_free() is deferred; remove first so indices don't include old nodes.
		grid.remove_child(child)
		child.queue_free()

	grid.columns = maxi(1, columns)

	if inventory == null:
		return

	var slots := inventory.slots
	var real_count := slots.size()
	var total_count := real_count
	if display_slot_count > 0:
		total_count = maxi(display_slot_count, real_count)

	for i in range(total_count):
		var data: InventorySlot = slots[i] if i < real_count else null

		var slot_view := SLOT_SCENE.instantiate()
		slot_view.custom_minimum_size = slot_size
		if slot_view is HotbarSlot:
			var s := slot_view as HotbarSlot
			var is_real := i < real_count
			if is_real:
				s.setup(inventory, i, true)
				s.set_locked(false)
				s.editable = is_editable
				s.clicked.connect(_on_slot_clicked)
				s.activated.connect(_on_slot_activated)
				s.dropped.connect(_on_slot_dropped)
				s.focus_entered.connect(_on_slot_focus_entered.bind(i))
			else:
				# Locked/blocked slot: render but do not allow interaction.
				s.setup(null, -1, false)
				s.set_locked(true)
				s.tooltip_text = locked_slot_tooltip
		grid.add_child(slot_view)

		if slot_view is HotbarSlot:
			var s := slot_view as HotbarSlot
			var hk := ""
			if show_hotkeys_on_first_row and i < maxi(1, columns) and i < hotkeys.size():
				hk = String(hotkeys[i])
			s.set_hotkey(hk)
			s.set_highlight(i == selected_index)
			s.set_moving(i == moving_source_index)
			if data != null and data.item_data != null and data.count > 0:
				s.set_item(data.item_data, data.count)
			else:
				s.set_item(null, 0)

	# Ensure something is focusable for keyboard navigation.
	call_deferred("_ensure_focus")


func _on_slot_clicked(index: int) -> void:
	selected_index = index
	_apply_slot_states()
	slot_clicked.emit(index)


func _on_slot_activated(index: int) -> void:
	# ENTER: pick up from focused slot, then swap into target slot.
	if inventory == null:
		return
	if index < 0 or index >= inventory.slots.size():
		return

	selected_index = index

	if moving_source_index < 0:
		# Only start moving if there's something in the slot.
		var src_slot := inventory.slots[index]
		var has_item := src_slot != null and src_slot.item_data != null and src_slot.count > 0
		if has_item:
			moving_source_index = index
	else:
		if moving_source_index == index:
			# Cancel.
			moving_source_index = -1
		else:
			inventory.swap_slots(moving_source_index, index)
			moving_source_index = -1

	_apply_slot_states()


func _on_slot_dropped(src_index: int, dest_index: int) -> void:
	if selected_index == src_index:
		selected_index = dest_index


func _on_slot_focus_entered(index: int) -> void:
	if selected_index != index:
		selected_index = index
		_apply_slot_states()
	slot_focused.emit(index)


func _apply_slot_states() -> void:
	if grid == null:
		return
	var children := grid.get_children()
	for i in range(children.size()):
		var c := children[i]
		if c is HotbarSlot:
			var s := c as HotbarSlot
			s.set_highlight(i == selected_index)
			s.set_moving(i == moving_source_index)


func _apply_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if preview_inventory == null:
		return

	rebind_inventory(preview_inventory)
	set_selected_index(preview_selected_index)


func _ensure_focus() -> void:
	if not is_visible_in_tree():
		return
	if grid == null:
		return
	# If a slot already has focus, keep it.
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and grid.is_ancestor_of(focused):
		return
	# Focus selected slot if possible; otherwise first slot.
	var idx := selected_index
	if idx < 0:
		idx = 0
	var children := grid.get_children()
	if idx >= 0 and idx < children.size() and children[idx] is Control:
		(children[idx] as Control).grab_focus()
	elif children.size() > 0 and children[0] is Control:
		(children[0] as Control).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or inventory == null or event == null:
		return

	# Allow toggling the player menu while the menu is open (Tab to close).
	if event.is_action_pressed(&"open_player_menu", false, true):
		if (
			Runtime != null
			and Runtime.game_flow != null
			and Runtime.game_flow.has_method("toggle_player_menu")
		):
			Runtime.game_flow.toggle_player_menu()
			accept_event()
		return

	# WASD/Arrows via player move actions (menu runs while paused).
	var dx := 0
	var dy := 0
	if event.is_action_pressed(&"move_left", false, true):
		dx = -1
	elif event.is_action_pressed(&"move_right", false, true):
		dx = 1
	elif event.is_action_pressed(&"move_up", false, true):
		dy = -1
	elif event.is_action_pressed(&"move_down", false, true):
		dy = 1

	if dx != 0 or dy != 0:
		_move_selection(dx, dy)
		accept_event()
		return

	# ENTER fallback if focus isn't inside a slot.
	if event.is_action_pressed(&"ui_accept", false, true) and selected_index >= 0:
		_on_slot_activated(selected_index)
		accept_event()


func _move_selection(dx: int, dy: int) -> void:
	if inventory == null or grid == null:
		return
	var count := inventory.slots.size()
	if count <= 0:
		return

	var idx := selected_index
	if idx < 0:
		idx = 0

	var cols := maxi(1, columns)
	var row := int(idx / float(cols))
	var col := int(idx % cols)

	var new_row := row + dy
	var new_col := col + dx

	# Clamp within the grid bounds (no wrap).
	if new_col < 0 or new_col >= cols:
		return
	if new_row < 0:
		return

	var new_idx := new_row * cols + new_col
	if new_idx < 0 or new_idx >= count:
		return

	selected_index = new_idx
	_apply_slot_states()

	var children := grid.get_children()
	if new_idx >= 0 and new_idx < children.size() and children[new_idx] is Control:
		(children[new_idx] as Control).grab_focus()
