class_name Player
extends CharacterBody2D

@export var player_balance_config: PlayerBalanceConfig
@export var player_input_config: PlayerInputConfig
@export var inventory: InventoryData

var money: int = 0
var input_enabled: bool = true

@onready var state_machine: StateMachine = $StateMachine
@onready var character_visual: CharacterVisual = $CharacterVisual
@onready var animated_sprite: AnimatedSprite2D = (
	character_visual.get_clock_sprite() if character_visual != null else null
)
@onready var hands_overlay: AnimatedSprite2D = $HandsOverlay
@onready var footsteps_component: FootstepsComponent = $Components/FootstepsComponent
@onready var raycell_component: RayCellComponent = $Components/RayCellComponent
@onready var sprite_shake_component: ShakeComponent = $Components/SpriteShakeComponent
@onready var tool_node: HandTool = $Components/Tool
@onready var tool_manager: ToolManager = $Components/ToolManager
@onready var placement_manager = $Components/PlacementManager
@onready var camera_shake_component: ShakeComponent = $Components/CameraShakeComponent
@onready var energy_component: EnergyComponent = $Components/EnergyComponent
@onready var carried_item_sprite: Sprite2D = $Carry/CarriedItem

var tool_visuals: Node = null
var equipment: Resource = null

const _EQUIP_SLOT_SHIRT: StringName = &"shirt"
const _EQUIP_SLOT_PANTS: StringName = &"pants"


func _ready() -> void:
	add_to_group(Groups.PLAYER)
	# Ensure our modular visual has a default appearance.
	if character_visual != null and character_visual.appearance == null:
		var a := CharacterAppearance.new()
		a.legs_variant = &"default"
		a.torso_variant = &"default"
		a.face_variant = &"male"
		a.hair_variant = &"mohawk"
		a.hands_top_variant = &"default"
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

	# Tool visuals are baked into the player scene (not spawned by AgentSpawner).
	# HandTool will drive this node to render the equipped tool.
	var tv := get_node_or_null(NodePath("ToolVisuals"))
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
	_sync_hands_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
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
		velocity = Vector2.ZERO
		if state_machine.current_state.name != PlayerStateNames.IDLE:
			state_machine.change_state(PlayerStateNames.IDLE)


func _on_state_binding_requested(state: State) -> void:
	state.bind_parent(self)
	state.animation_change_requested.connect(_on_animation_change_requested)


func set_tool_visuals(node: Node) -> void:
	tool_visuals = node
	if tool_node != null and tool_node.has_method("set_tool_visuals"):
		tool_node.call("set_tool_visuals", tool_visuals)


func _on_animation_change_requested(animation_name: StringName) -> void:
	if raycell_component == null or not is_instance_valid(raycell_component):
		return
	var dir_suffix := _direction_suffix(raycell_component.facing_dir)
	var directed := StringName(str(animation_name, "_", dir_suffix))

	# Body (layered)
	if character_visual == null:
		return
	character_visual.play_directed(animation_name, raycell_component.facing_dir)
	# Ensure our clock reference stays valid for tool states + hands overlay sync.
	animated_sprite = character_visual.get_clock_sprite()

	# Hands overlay (only for tool-use anims)
	# NOTE: You can omit `front/back` overlays; we just hide if missing.
	var wants_hands := animation_name == &"swing" or animation_name == &"use"
	if hands_overlay == null:
		return

	if not wants_hands:
		hands_overlay.visible = false
		hands_overlay.stop()
		return

	if hands_overlay.sprite_frames and hands_overlay.sprite_frames.has_animation(directed):
		hands_overlay.visible = true
		if hands_overlay.animation != directed:
			hands_overlay.play(directed)
	else:
		hands_overlay.visible = false
		hands_overlay.stop()


func _sync_hands_overlay() -> void:
	if hands_overlay == null or not hands_overlay.visible:
		return
	if animated_sprite == null:
		return
	# Frame-perfect sync to the body so there is no drift.
	hands_overlay.frame = animated_sprite.frame
	hands_overlay.frame_progress = animated_sprite.frame_progress
	hands_overlay.speed_scale = animated_sprite.speed_scale


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
	if raycell_component != null:
		raycell_component.facing_dir = rec.facing_dir

	# Appearance / equipment (persisted in AgentRecord).
	if rec.appearance != null and character_visual != null:
		character_visual.appearance = rec.appearance
	if rec.equipment != null:
		equipment = rec.equipment
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

	if not equipment.has_method("get_equipped_item_id"):
		return

	# Shirt
	var shirt_id: StringName = equipment.call("get_equipped_item_id", _EQUIP_SLOT_SHIRT)
	var shirt_item: ItemData = ItemResolver.resolve(shirt_id)
	if shirt_item is ClothingItemData:
		var ci := shirt_item as ClothingItemData
		a.shirt_variant = ci.variant
	else:
		# Unequipped (or invalid item): clear the clothing layer.
		a.shirt_variant = &""

	# Pants / boots
	var pants_id: StringName = equipment.call("get_equipped_item_id", _EQUIP_SLOT_PANTS)
	var pants_item: ItemData = ItemResolver.resolve(pants_id)
	if pants_item is ClothingItemData:
		var ci2 := pants_item as ClothingItemData
		a.pants_variant = ci2.variant
	else:
		# Unequipped (or invalid item): clear the clothing layer.
		a.pants_variant = &""

	# Force CharacterVisual to re-apply slot frames/materials.
	character_visual.appearance = a
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
	if (
		equipment == null
		or not (equipment is Resource)
		or equipment.get_script() != PlayerEquipment
	):
		equipment = PlayerEquipment.new()


func get_equipped_item_id(slot: StringName) -> StringName:
	_ensure_default_equipment()
	if equipment == null or not equipment.has_method("get_equipped_item_id"):
		return &""
	var v: Variant = equipment.call("get_equipped_item_id", slot)
	return v as StringName if v is StringName else &""


func set_equipped_item_id(slot: StringName, item_id: StringName) -> void:
	_ensure_default_equipment()
	if equipment == null or not equipment.has_method("set_equipped_item_id"):
		return
	equipment.call("set_equipped_item_id", slot, item_id)
	_apply_equipment_to_appearance()
