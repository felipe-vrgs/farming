class_name ItemPopover
extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var meta_label: Label = %MetaLabel
@onready var value_label: Label = %ValueLabel
@onready var action_label: Label = %ActionLabel

const _MIN_WIDTH: float = 240.0
const _DEFAULT_WIDTH: float = 270.0
const _MAX_WIDTH: float = 360.0


func set_item(item: ItemData, count: int, slot: StringName, is_equipped: bool) -> void:
	if item == null:
		visible = false
		return

	visible = true
	# Make the width deterministic so Labels with autowrap can't cause a huge first-layout width.
	custom_minimum_size.x = clampf(_DEFAULT_WIDTH, _MIN_WIDTH, _MAX_WIDTH)
	size.x = custom_minimum_size.x

	if icon_rect != null:
		icon_rect.texture = item.icon if item.icon is Texture2D else null

	if name_label != null:
		if count > 1:
			name_label.text = "%s (x%d)" % [item.display_name, int(count)]
		else:
			name_label.text = String(item.display_name)

	if desc_label != null:
		var desc := String(item.description).strip_edges()
		if desc.is_empty():
			desc = "(No description)"
		desc_label.text = desc

	if meta_label != null:
		var slot_txt := String(slot).strip_edges()
		# For non-clothing items we typically pass an empty slot; don't show "Slot: -".
		# For equipped items (equipment popover) we always have a slot name.
		if slot_txt.is_empty() and not is_equipped:
			meta_label.visible = false
		else:
			meta_label.visible = true
			var equip_txt := "Equipped" if is_equipped else ""
			if slot_txt.is_empty():
				meta_label.text = equip_txt
			elif equip_txt.is_empty():
				meta_label.text = "Slot: %s" % slot_txt
			else:
				meta_label.text = "Slot: %s    %s" % [slot_txt, equip_txt]

	if value_label != null:
		var buy := int(item.buy_price)
		var sell := int(item.sell_price)
		if buy == sell:
			value_label.text = "Value: %d" % sell
		else:
			value_label.text = "Sell: %d   Buy: %d" % [sell, buy]

	if action_label != null:
		# We no longer show "Press enter to equip" here (equip is via drag/drop or double-click).
		action_label.visible = false

	# Size to fit content (used when positioning/clamping).
	# We compute height on the next frame after layout has settled.
	call_deferred("_recalc_size")


func _recalc_size() -> void:
	# Keep width fixed, recalc height based on wrapped content.
	var w := clampf(custom_minimum_size.x, _MIN_WIDTH, _MAX_WIDTH)
	custom_minimum_size.x = w
	size.x = w
	reset_size()  # sets size to minimum size
	size.x = w


func hide_popover() -> void:
	visible = false
