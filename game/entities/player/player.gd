class_name Player
extends CharacterBody2D

const _TOOL_VISUALS_SCENE := preload("res://game/entities/tools/tool_visuals.tscn")

@export var player_balance_config: PlayerBalanceConfig
@export var player_input_config: PlayerInputConfig
@export var inventory: InventoryData

var money: int = 999
var input_enabled: bool = true
var action_input_enabled: bool = true
var display_name: String = "Player"

@onready var state_machine: StateMachine = $StateMachine
@onready var character_visual: CharacterVisual = $CharacterVisual
@onready var animated_sprite: AnimatedSprite2D = (
	character_visual.get_clock_sprite() if character_visual != null else null
)
@onready var footsteps_component: FootstepsComponent = $Components/FootstepsComponent
@onready var raycell_component: RayCellComponent = $Components/RayCellComponent
@onready var sprite_shake_component: ShakeComponent = $Components/SpriteShakeComponent
@onready var tool_node: HandTool = $Components/Tool
@onready var tool_manager: ToolManager = $Components/ToolManager
@onready var placement_manager = $Components/PlacementManager
@onready var camera_shake_component: ShakeComponent = $Components/CameraShakeComponent
@onready var energy_component: EnergyComponent = $Components/EnergyComponent
@onready var carried_item_sprite: Sprite2D = $Carry/CarriedItem
@onready var night_light: Light2D = $NightLight

var tool_visuals: Node = null
var equipment: PlayerEquipment = null


func _ready() -> void:
	add_to_group(Groups.PLAYER)
	# Ensure our modular visual has a default appearance.
	if character_visual != null and character_visual.appearance == null:
		var a := CharacterAppearance.new()
		a.legs_variant = &"default"
		a.shoes_variant = &"brown"
		a.torso_variant = &"default"
		a.hands_variant = &"default"
		a.face_variant = &"male"
		a.hair_variant = &"mohawk"
		character_visual.appearance = a

	# Ensure we have default equipment (paperdoll).
	_ensure_default_equipment()
	_apply_equipment_to_appearance()
	# Refresh clock sprite reference (CharacterVisual owns the AnimatedSprite2D).
	if character_visual != null:
		animated_sprite = character_visual.get_clock_sprite()
	if inventory == null:
		inventory = preload("res://game/entities/player/player_inventory.tres")

	# Avoid mutating shared `.tres` resources from `res://` (inventory should be per-session).
	if inventory != null and String(inventory.resource_path).begins_with("res://"):
		inventory = inventory.duplicate(true)

	# Initialize Input Map
	player_input_config.ensure_actions_registered()

	# Connect to state machine binding request
	state_machine.state_binding_requested.connect(_on_state_binding_requested)

	ZLayers.apply_world_entity(self)

	# Initialize State Machine
	state_machine.init()

	# Start with no carried item visual.
	set_carried_item(null)
	set_night_light_enabled(false)

	# Tool visuals are baked into the player scene (not spawned by AgentSpawner).
	# HandTool will drive this node to render the equipped tool.
	var tv := get_node_or_null(NodePath("CharacterVisual/ToolLayer/ToolVisuals"))
	if tv == null:
		# Back-compat (older scene layout).
		tv = get_node_or_null(NodePath("CharacterVisual/ToolVisuals"))
	if tv == null:
		# Back-compat (older scene layout).
		tv = get_node_or_null(NodePath("ToolVisuals"))
	if tv == null:
		tv = _ensure_tool_visuals_node()
	if tv != null:
		set_tool_visuals(tv)
	# Ensure tool visuals reference is propagated if already set.
	if tool_node != null and tool_visuals != null and tool_node.has_method("set_tool_visuals"):
		tool_node.call("set_tool_visuals", tool_visuals)

	# Energy / exhaustion handling (sleep pipeline is owned by Runtime).
	if energy_component != null:
		var cb := Callable(self, "_on_energy_depleted")
		if not energy_component.depleted.is_connected(cb):
			energy_component.depleted.connect(cb)


func _on_energy_depleted() -> void:
	# Avoid doing anything while input is already disabled (sleep/loads/etc).
	if not input_enabled:
		return
	if Runtime != null and Runtime.has_method("request_exhaustion_sleep"):
		Runtime.call_deferred("request_exhaustion_sleep")


func set_carried_item(item: ItemData) -> void:
	# Visual layer for "holding item overhead".
	if carried_item_sprite != null:
		if item != null and item.icon is Texture2D:
			carried_item_sprite.texture = item.icon
			carried_item_sprite.visible = true
		else:
			carried_item_sprite.texture = null
			carried_item_sprite.visible = false

	# Hide hand tool while carrying a non-tool item.
	if tool_node != null:
		tool_node.visible = item == null or item is ToolData


func _physics_process(delta: float) -> void:
	# During scene transitions / hydration, the player can be queued-freed.
	# Avoid touching freed components.
	if not is_inside_tree():
		return
	if raycell_component == null or not is_instance_valid(raycell_component):
		return
	if state_machine == null or not is_instance_valid(state_machine):
		return

	if not input_enabled:
		move_and_slide()
		return

	state_machine.process_physics(delta)
	# Update the raycell component with the player's velocity and position
	raycell_component.update_aim(velocity, global_position - Vector2.UP * 4)
	move_and_slide()


func _process(delta: float) -> void:
	state_machine.process_frame(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if not action_input_enabled:
		return

	var index: int = -1
	var actions := [
		player_input_config.action_hotbar_1,
		player_input_config.action_hotbar_2,
		player_input_config.action_hotbar_3,
		player_input_config.action_hotbar_4,
		player_input_config.action_hotbar_5,
		player_input_config.action_hotbar_6,
		player_input_config.action_hotbar_7,
		player_input_config.action_hotbar_8,
		player_input_config.action_hotbar_9,
		player_input_config.action_hotbar_0,
	]
	for i in range(actions.size()):
		if event.is_action_pressed(actions[i]):
			index = i
			break

	if index >= 0:
		if tool_manager != null and tool_manager.has_method("select_hotbar_slot"):
			tool_manager.call("select_hotbar_slot", index)
		else:
			# Back-compat (older ToolManager API).
			tool_manager.select_tool(index)
		return

	state_machine.process_input(event)


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled

	if not input_enabled:
		# Freeze the player while menus/loads/etc are active.
		velocity = Vector2.ZERO
		if (
			state_machine != null
			and state_machine.current_state != null
			and state_machine.current_state.name != PlayerStateNames.IDLE
		):
			state_machine.change_state(PlayerStateNames.IDLE)
		return

	# Re-sync the player stance/state from the current hotbar selection.
	# (Opening menus disables input, which previously forced IDLE and lost carry stance.)
	var in_item_mode := false
	if (
		tool_manager != null
		and is_instance_valid(tool_manager)
		and tool_manager.has_method("is_in_item_mode")
	):
		in_item_mode = bool(tool_manager.call("is_in_item_mode"))

	if state_machine != null and state_machine.current_state != null:
		if in_item_mode:
			state_machine.change_state(PlayerStateNames.PLACEMENT)
		else:
			state_machine.change_state(PlayerStateNames.IDLE)

	# Ensure the layered visuals immediately reflect the restored stance even before movement input.
	_refresh_visual_layers_after_appearance_change()


func set_action_input_enabled(enabled: bool) -> void:
	action_input_enabled = enabled


func set_night_light_enabled(enabled: bool) -> void:
	if night_light == null or not is_instance_valid(night_light):
		return
	night_light.visible = enabled


func _on_state_binding_requested(state: State) -> void:
	state.bind_parent(self)
	state.animation_change_requested.connect(_on_animation_change_requested)


func set_tool_visuals(node: Node) -> void:
	tool_visuals = node
	if tool_node != null and tool_node.has_method("set_tool_visuals"):
		tool_node.call("set_tool_visuals", tool_visuals)


func _ensure_tool_visuals_node() -> Node:
	# Safety net: if the ToolVisuals instance was accidentally removed from the Player scene
	# (common when tweaking CharacterVisual for hitbox work), create it at runtime so tools
	# still render and tests/CI can catch the regression.
	var cv := get_node_or_null(NodePath("CharacterVisual"))
	if cv == null:
		return null

	var tool_layer := cv.get_node_or_null(NodePath("ToolLayer"))
	if tool_layer == null:
		tool_layer = Node2D.new()
		tool_layer.name = "ToolLayer"
		# Prefer placing ToolLayer before Hands if present; otherwise append.
		var hands := cv.get_node_or_null(NodePath("Hands"))
		if hands != null:
			cv.add_child(tool_layer)
			cv.move_child(tool_layer, hands.get_index())
		else:
			cv.add_child(tool_layer)

	# Avoid duplicates if something else already spawned it.
	var existing := tool_layer.get_node_or_null(NodePath("ToolVisuals"))
	if existing != null:
		return existing

	var inst := _TOOL_VISUALS_SCENE.instantiate()
	if inst == null:
		return null
	inst.name = "ToolVisuals"
	tool_layer.add_child(inst)
	return inst


func _on_animation_change_requested(animation_name: StringName) -> void:
	if raycell_component == null or not is_instance_valid(raycell_component):
		return

	# Body (layered)
	if character_visual == null:
		return
	character_visual.play_directed(animation_name, raycell_component.facing_dir)
	# Ensure our clock reference stays valid for tool states + hands overlay sync.
	animated_sprite = character_visual.get_clock_sprite()


func _direction_suffix(dir: Vector2) -> String:
	# Match your existing move_* convention.
	if abs(dir.x) >= abs(dir.y):
		# Godot: +X is right, -X is left.
		return "right" if dir.x > 0.0 else "left"
	return "front" if dir.y > 0.0 else "back"


func set_terrain_collision(enabled: bool) -> void:
	const TERRAIN_BIT := 1 << 1  # Layer 2
	const GUARDRAILS_BIT := 1 << 2  # Layer 3
	const NPC_BIT := 1 << 3  # Layer 4
	const ITEMS_BIT := 1 << 4  # Layer 5 (WorldItem Area2D uses collision_layer=16)
	if enabled:
		collision_mask = TERRAIN_BIT | GUARDRAILS_BIT | NPC_BIT | ITEMS_BIT  # 30
	else:
		# Keep item pickup enabled even when terrain collision is disabled (wall pass zones, etc.).
		# Keep NPC collision enabled (terrain toggle should not affect NPC collision policy).
		collision_mask = GUARDRAILS_BIT | NPC_BIT | ITEMS_BIT  # 28


func recoil() -> void:
	if sprite_shake_component:
		sprite_shake_component.start_shake()

	if camera_shake_component:
		camera_shake_component.start_shake()


func apply_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	if "display_name" in rec and not String(rec.display_name).is_empty():
		display_name = String(rec.display_name)
	if raycell_component != null:
		raycell_component.facing_dir = rec.facing_dir

	# Appearance / equipment (persisted in AgentRecord).
	if rec.appearance != null and character_visual != null:
		character_visual.appearance = rec.appearance
	if rec.equipment != null:
		equipment = rec.equipment as PlayerEquipment
	_ensure_default_equipment()
	_apply_equipment_to_appearance()

	# Restore per-day energy state (if present in save).
	if energy_component != null and is_instance_valid(energy_component):
		if "energy_current" in rec and float(rec.energy_current) >= 0.0:
			energy_component.set_energy(float(rec.energy_current), -1.0, true)
		if "energy_forced_wakeup_pending" in rec and bool(rec.energy_forced_wakeup_pending):
			energy_component.set_forced_wakeup_pending()
		else:
			energy_component.clear_forced_wakeup_pending()

	# If already idle, refresh animation to match new facing_dir
	if state_machine != null and state_machine.current_state != null:
		if String(state_machine.current_state.name).to_snake_case() == PlayerStateNames.IDLE:
			state_machine.change_state(PlayerStateNames.IDLE)


func capture_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	rec.display_name = String(display_name)
	if raycell_component != null:
		rec.facing_dir = raycell_component.facing_dir

	# Persist appearance/equipment.
	if character_visual != null:
		rec.appearance = character_visual.appearance
	rec.equipment = equipment

	if energy_component != null and is_instance_valid(energy_component):
		rec.energy_current = float(energy_component.current_energy)
		if energy_component.has_method("is_forced_wakeup_pending"):
			rec.energy_forced_wakeup_pending = bool(
				energy_component.call("is_forced_wakeup_pending")
			)


func _apply_equipment_to_appearance() -> void:
	# Equipment drives clothing variants on top of the base appearance.
	if character_visual == null:
		return
	var a := character_visual.appearance
	if a == null:
		return
	if equipment == null:
		return

	# Shirt
	var shirt_id: StringName = equipment.get_equipped_item_id(EquipmentSlots.SHIRT)
	var shirt_item: ItemData = ItemResolver.resolve(shirt_id)
	if shirt_item is ClothingItemData:
		var ci := shirt_item as ClothingItemData
		a.shirt_variant = ci.variant
	else:
		# Unequipped (or invalid item): clear the clothing layer.
		a.shirt_variant = &""

	# Pants / boots
	var pants_id: StringName = equipment.get_equipped_item_id(EquipmentSlots.PANTS)
	var pants_item: ItemData = ItemResolver.resolve(pants_id)
	if pants_item is ClothingItemData:
		var ci2 := pants_item as ClothingItemData
		a.pants_variant = ci2.variant
	else:
		# Unequipped (or invalid item): clear the clothing layer.
		a.pants_variant = &""

	# Shoes
	var shoes_id: StringName = equipment.get_equipped_item_id(EquipmentSlots.SHOES)
	var shoes_item: ItemData = ItemResolver.resolve(shoes_id)
	if shoes_item is ClothingItemData:
		var ci3 := shoes_item as ClothingItemData
		a.shoes_variant = ci3.variant
	else:
		# Unequipped (or invalid item): clear the clothing layer.
		a.shoes_variant = &""

	# Force CharacterVisual to re-apply slot frames/materials.
	# `CharacterVisual.appearance` is usually the same Resource instance; reassigning it is a no-op.
	# Emitting `changed` is the supported way to notify listeners that properties changed.
	a.emit_changed()
	_refresh_visual_layers_after_appearance_change()


func _refresh_visual_layers_after_appearance_change() -> void:
	# When equipping a new layer (e.g. shirt), `_apply_appearance()` loads frames but does not
	# force visibility. If the player is paused (menu), the next animation change may not fire
	# until input happens. Force a replay of the current base animation so layers show instantly.
	if character_visual == null:
		return
	var dir := Vector2.DOWN
	if raycell_component != null and is_instance_valid(raycell_component):
		dir = raycell_component.facing_dir

	var base: StringName = &"idle"
	var moving := velocity.length() > 0.1
	var in_item_mode := false
	if (
		tool_manager != null
		and is_instance_valid(tool_manager)
		and tool_manager.has_method("is_in_item_mode")
	):
		in_item_mode = bool(tool_manager.call("is_in_item_mode"))
	if in_item_mode:
		base = &"carry_move" if moving else &"carry_idle"
	else:
		base = &"move" if moving else &"idle"

	character_visual.play_directed(base, dir)


func _ensure_default_equipment() -> void:
	# Ensure `equipment` is a PlayerEquipment resource, and seed defaults when empty.
	if equipment == null or not (equipment is PlayerEquipment):
		equipment = PlayerEquipment.new()


func get_equipped_item_id(slot: StringName) -> StringName:
	_ensure_default_equipment()
	if equipment == null:
		return &""
	return equipment.get_equipped_item_id(slot)


func set_equipped_item_id(slot: StringName, item_id: StringName) -> void:
	_ensure_default_equipment()
	if equipment == null:
		return
	equipment.set_equipped_item_id(slot, item_id)
	_apply_equipment_to_appearance()


func try_equip_clothing_from_inventory(index: int, target_slot: StringName = &"") -> bool:
	# Equip 1 clothing item from an inventory slot index.
	# Swap behavior: if something is already equipped in that slot, return it to inventory.
	var success := false

	var inv: InventoryData = inventory
	var inv_slot: InventorySlot = null
	var item: ItemData = null
	var slot: StringName = &""

	if inv != null and index >= 0 and index < inv.slots.size():
		inv_slot = inv.slots[index]
	if inv_slot != null and inv_slot.item_data != null and inv_slot.count > 0:
		item = inv_slot.item_data
	if item is ClothingItemData:
		slot = (item as ClothingItemData).slot

	if inv == null or inv_slot == null or item == null or String(slot).is_empty():
		success = false
	elif not String(target_slot).is_empty() and slot != target_slot:
		# Dragging to a specific equipment slot should only work if it matches.
		if UIManager != null and UIManager.has_method("show_toast"):
			UIManager.show_toast("That doesn't fit there.")
		success = false
	else:
		# Remove the item first (frees an inventory slot for swap-back if needed).
		var removed := inv.remove_from_slot(index, 1)
		if removed > 0:
			var new_id: StringName = item.id
			var old_id: StringName = get_equipped_item_id(slot)
			if not String(old_id).is_empty() and old_id != new_id:
				var old_item: ItemData = ItemResolver.resolve(old_id)
				if old_item != null:
					var remaining := inv.add_item(old_item, 1)
					if remaining > 0 and UIManager != null and UIManager.has_method("show_toast"):
						UIManager.show_toast("Inventory full: equipped item was lost.")
				elif UIManager != null and UIManager.has_method("show_toast"):
					UIManager.show_toast("Missing equipped item resource: %s" % String(old_id))

			set_equipped_item_id(slot, new_id)
			success = true

	return success


func try_unequip_clothing_to_inventory(slot: StringName) -> bool:
	# Unequip 1 clothing item from a slot and return it to inventory.
	if inventory == null:
		return false
	var old_id: StringName = get_equipped_item_id(slot)
	if String(old_id).is_empty():
		return false

	var old_item: ItemData = ItemResolver.resolve(old_id)
	if old_item == null:
		# If the item resource is missing, clear to avoid a broken equipped state.
		set_equipped_item_id(slot, &"")
		if UIManager != null and UIManager.has_method("show_toast"):
			UIManager.show_toast("Missing equipped item resource: %s" % String(old_id))
		return true

	var remaining := inventory.add_item(old_item, 1)
	if remaining > 0:
		if UIManager != null and UIManager.has_method("show_toast"):
			UIManager.show_toast("Inventory full: cannot unequip right now.")
		return false

	set_equipped_item_id(slot, &"")
	return true
